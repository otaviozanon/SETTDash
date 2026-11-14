
# ================================================
#region BACKGROUND JOBS (scans / long cleanups off the UI thread)
# ================================================
# A WPF window freezes while its UI thread is inside a long call - the recursive size walk done by
# the System Cleaner scan is the worst offender, and Full Cleanup can spend many seconds deleting.
# These helpers run that work in a dedicated runspace instead and hand the result back on the UI
# thread (DispatcherTimer polling, never a blocking wait), so the window keeps painting and the
# button that started the job turns into "Cancel".
#
# A fresh runspace has none of the app's functions, so the entry scriptblock's dependency tree is
# copied in as source (functions only). The $Script: variables those bodies read are passed by
# reference. WPF objects are never touched by the worker: Write-GuiLog / Set-GuiProgress /
# Clear-GuiLog are shadowed inside the runspace by versions that append to a thread-safe queue,
# which the UI thread replays - a control may only be touched by the thread that created it.

# Jobs still running, so Clear-GuiContent can cancel them when the page that started them is torn
# down. Otherwise a scan keeps working (and its OnDone keeps writing into detached controls) after
# the user navigates away.
$Script:ActiveGuiJobs = New-Object System.Collections.ArrayList

# Resolves the transitive function closure of $Names and returns it as PowerShell source text.
# Throws (before any work starts) when a name cannot be resolved, so a job never dies halfway
# through a cleanup because a helper was missing.
function Get-GuiFunctionBundle {
    param([string[]]$Names)
    $seen = New-Object 'System.Collections.Generic.HashSet[string]'
    $queue = New-Object System.Collections.Queue
    foreach ($n in $Names) { [void]$queue.Enqueue($n) }
    $sb = New-Object System.Text.StringBuilder
    while ($queue.Count -gt 0) {
        $name = [string]$queue.Dequeue()
        if (-not $seen.Add($name)) { continue }
        $cmd = Get-Command -Name $name -CommandType Function -ErrorAction SilentlyContinue
        if (-not $cmd) { throw "Background job: function '$name' is not defined" }
        # Module functions must NOT be copied: ScheduledTasks (and other CDXML modules) export
        # proxy functions such as Get-ScheduledTask, and re-defining one from its definition alone
        # shadows the real cmdlet and breaks its dynamic parameters ("You cannot call a method on
        # a null-valued expression"), which a scan's catch then reports as "nothing found".
        # Module functions are auto-loaded inside the runspace, so skipping them is enough.
        if ($cmd.ModuleName) { continue }
        [void]$sb.AppendLine("function $name {")
        [void]$sb.AppendLine($cmd.Definition)
        [void]$sb.AppendLine("}")
        foreach ($m in [regex]::Matches($cmd.Definition, '\b([A-Za-z][A-Za-z0-9]*-[A-Za-z][A-Za-z0-9]*)\b')) {
            $candidate = $m.Groups[1].Value
            if ($seen.Contains($candidate)) { continue }
            if (Get-Command -Name $candidate -CommandType Function -ErrorAction SilentlyContinue) { [void]$queue.Enqueue($candidate) }
        }
    }
    return $sb.ToString()
}

# Starts $Work in its own runspace. Returns a state object (Stop-GuiBackgroundJob cancels it).
# $OnDone receives the pipeline output on the UI thread, only when the job finished cleanly.
# $Button (optional) gets its text restored and reads "Cancel" until then.
function Start-GuiBackgroundJob {
    param(
        [scriptblock]$Work,
        [string[]]$Functions,
        [scriptblock]$OnDone = $null,
        $Button = $null,
        [string]$Name = "Background job",
        # Values the worker needs but that are not $Script: variables (a page's local selection
        # list, a resolved exe path). They are injected as script-scope variables in the runspace.
        [hashtable]$Arguments = @{}
    )

    $bundle = Get-GuiFunctionBundle -Names $Functions

    # $Script: variables read by the copied bodies are passed by reference (plain values here:
    # paths, booleans). Never invoke anything from the worker that reaches WPF. The work block
    # itself is scanned too: page scans read $Script: flags (e.g. ShowMicrosoftServices).
    $workText = $Work.ToString()
    $vars = @{}
    foreach ($m in [regex]::Matches($bundle + $workText, '\$Script:([A-Za-z_][A-Za-z0-9_]*)')) {
        $varName = $m.Groups[1].Value
        if ($vars.ContainsKey($varName)) { continue }
        $v = Get-Variable -Name $varName -Scope Script -ErrorAction SilentlyContinue
        $vars[$varName] = if ($v) { $v.Value } else { $null }
    }

    $logQueue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]'
    $navQueue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]'
    foreach ($k in $Arguments.Keys) { $vars[[string]$k] = $Arguments[$k] }
    $vars['BgLogQueue'] = $logQueue
    $vars['BgNavQueue'] = $navQueue
    $vars['BgProgress'] = @{ Value = 0 }
    # Lets a helper that normally backgrounds itself (Invoke-InstallWingetApp) run inline when it is
    # already inside a job - a nested job would escape the batch and run installs in parallel.
    $vars['BgWorker'] = $true

    $scriptText = "param(`$ScriptValues)`n"
    $scriptText += "foreach (`$k in `$ScriptValues.Keys) { Set-Variable -Name `$k -Value `$ScriptValues[`$k] -Scope Script }`n"
    $scriptText += $bundle
    # These MUST come after the copied bundle so the queue versions win over the real GUI ones.
    $scriptText += @'
function Write-GuiLog { param([string]$Message, [string]$Type = "INFO") [void]$Script:BgLogQueue.Enqueue(@{ Message = $Message; Type = $Type }) }
function Set-GuiProgress { param([double]$Value, [string]$Status) if ($Status) { [void]$Script:BgLogQueue.Enqueue(@{ Message = $Status; Type = "STEP" }) }; $Script:BgProgress.Value = $Value }
function Clear-GuiLog { }
# Sidebar "applied" dots live on the UI thread; queue them and let the tick replay them.
function Set-NavStatus { param([string]$Name, [bool]$Applied) [void]$Script:BgNavQueue.Enqueue(@{ Name = $Name; Applied = $Applied }) }
'@
    $scriptText += "`n" + $Work.ToString()

    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.ApartmentState = 'MTA'
    $runspace.ThreadOptions = 'ReuseThread'
    $runspace.Open()
    $shell = [powershell]::Create()
    $shell.Runspace = $runspace
    [void]$shell.AddScript($scriptText)
    [void]$shell.AddArgument($vars)

    $state = [pscustomobject]@{
        Shell      = $shell
        Runspace   = $runspace
        Handle     = $null
        Done       = $false
        Cancelled  = $false
        Timer      = $null
        LogQueue   = $logQueue
        NavQueue   = $navQueue
        ProgressBox = $vars['BgProgress']
        Button     = $Button
        ButtonText = if ($Button) { [string]$Button.Content } else { "" }
        Name       = $Name
        OnDone     = $OnDone
    }
    $state.Handle = $shell.BeginInvoke()
    [void]$Script:ActiveGuiJobs.Add($state)
    if ($Button) { $Button.Content = T "Cancel" }

    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(150)
    $timer.Tag = $state

    # Captured before GetNewClosure(): inside a closure $Script: points at the closure's own empty
    # scope, so a direct $Script:ActiveGuiJobs there is $null.
    $activeJobs = $Script:ActiveGuiJobs

    $tick = {
        param($s, $e)
        $st = $s.Tag
        $entry = $null
        while ($st.LogQueue.TryDequeue([ref]$entry)) { Write-GuiLog $entry.Message $entry.Type }
        $nav = $null
        while ($st.NavQueue.TryDequeue([ref]$nav)) { try { Set-NavStatus $nav.Name $nav.Applied } catch { } }
        if ($null -ne $st.ProgressBox -and $st.ProgressBox.Value -gt 0) { Set-GuiProgress $st.ProgressBox.Value }
        if (-not $st.Handle.IsCompleted) { return }

        $st.Timer.Stop()
        $st.Done = $true
        [void]$activeJobs.Remove($st)
        if ($st.Button) { $st.Button.Content = $st.ButtonText }
        $result = $null; $errorText = ""
        try {
            $result = $st.Shell.EndInvoke($st.Handle)
            $errs = @($st.Shell.Streams.Error)
            if ($errs.Count -gt 0) { $errorText = $errs[0].ToString() }
        } catch {
            $errorText = $_.Exception.Message
        }
        while ($st.LogQueue.TryDequeue([ref]$entry)) { Write-GuiLog $entry.Message $entry.Type }
        while ($st.NavQueue.TryDequeue([ref]$nav)) { try { Set-NavStatus $nav.Name $nav.Applied } catch { } }
        try { $st.Shell.Dispose() } catch { }
        try { $st.Runspace.Dispose() } catch { }

        if ($errorText) {
            Set-GuiProgress 0
            Write-GuiLog ((T "{0} failed: {1}") -f $st.Name, $errorText) "ERR"
        } elseif ($st.OnDone) {
            try { & $st.OnDone $result } catch { Write-GuiLog ((T "{0} completion failed: {1}") -f $st.Name, $_.Exception.Message) "ERR"; Set-GuiProgress 0 }
        }
    }.GetNewClosure()
    $timer.Add_Tick($tick)
    $state.Timer = $timer
    $timer.Start()
    return $state
}

# Cancels a running job (the button that started it reads "Cancel" meanwhile).
function Stop-GuiBackgroundJob {
    param($State)
    if (-not $State -or $State.Done) { return }
    $State.Cancelled = $true
    $State.Done = $true
    if ($State.Timer) { $State.Timer.Stop() }
    try { if ($State.Shell) { $State.Shell.Stop() } } catch { }
    try { if ($State.Shell) { $State.Shell.Dispose() } } catch { }
    try { if ($State.Runspace) { $State.Runspace.Dispose() } } catch { }
    if ($State.Button) { $State.Button.Content = $State.ButtonText }
    [void]$Script:ActiveGuiJobs.Remove($State)
    Set-GuiProgress 0
    Write-GuiLog ((T "{0} cancelled") -f $State.Name) "WARN"
}

# Cancels every job still running. Used by Clear-GuiContent: navigating away from a page must not
# leave its scan running against controls that no longer exist.
function Stop-AllGuiBackgroundJobs {
    if (-not (Get-Variable -Name ActiveGuiJobs -Scope Script -ErrorAction SilentlyContinue)) { return }
    foreach ($state in @($Script:ActiveGuiJobs)) { Stop-GuiBackgroundJob -State $state }
}

# Button that runs $Work in the background (scan, Full Cleanup, ...). First click starts it;
# while it runs the button reads "Cancel" and a second click stops it. $Confirm (optional) is
# asked first and must return $true to proceed. $OnDone runs on the UI thread with the result.
function Add-GuiBackgroundBtn {
    param($Panel, [string]$Text, [scriptblock]$Work, [string[]]$Functions, [scriptblock]$OnDone,
          [string]$Style = "ActionButtonStyle", [scriptblock]$ConfirmCheck = $null)
    $btn = New-Object System.Windows.Controls.Button
    $styleObj = $Window.FindResource($Style); if ($styleObj) { $btn.Style = $styleObj }
    $btn.MinWidth = 100
    $btn.Margin = "0,2,5,2"
    $btn.Content = $Text
    $btn.Add_Click({
        if ($btn.Tag -and -not $btn.Tag.Done) { Stop-GuiBackgroundJob -State $btn.Tag; return }
        if ($ConfirmCheck -and -not (& $ConfirmCheck)) { return }
        Clear-GuiLog
        Set-GuiProgress 0
        $btn.Tag = Start-GuiBackgroundJob -Work $Work -Functions $Functions -OnDone $OnDone -Button $btn -Name $Text
    }.GetNewClosure())
    $Panel.AddChild($btn)
    return $btn
}
#endregion

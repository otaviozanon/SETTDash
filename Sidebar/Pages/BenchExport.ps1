# "Benchmark > Export" page: summarizes the cached results (kept in $Global:Bench*LastResult,
# set by each benchmark page's "Run Benchmark" handler and cleared only when the program closes)
# and reuses the same category-picker/detail-card layout + "Export Report" -> HTML -> browser
# print-to-PDF flow as the "Your PC" pages (Show-GuiCategoryDetailPage / Export-GuiSystemReport
# in Core/Helpers/Cards.ps1) so Benchmark gets an identical export experience.
function Show-PageBenchExport {
    Clear-GuiContent
    Add-GuiPageTitle "Export Benchmarks"

    $fmtStatus = { param($r) if ($r.Cancelled) { "Stopped (partial)" } else { "Complete" } }
    $fmtTime = { param($r) $r.Timestamp.ToString("yyyy-MM-dd HH:mm:ss") }

    # Each category is a scriptblock that OUTLIVES this function: the pill click handler and the
    # HTML export invoke it long after Show-PageBenchExport returned. A plain scriptblock only keeps
    # its own scope, so the outer locals were already gone by then and every click on a category with
    # data threw "The variable '$fmtStatus' cannot be retrieved because it has not been set" (and the
    # "All" pill the same for $categories). GetNewClosure() gives each one a private snapshot.
    $categories = [ordered]@{}
    $categories["All"] = {
        $all = @()
        foreach ($name in @("CPU", "GPU", "RAM", "Disk")) {
            $all += @{IsHeader=$true; Label=$name}
            $all += (& $categories[$name])
        }
        $all
    }.GetNewClosure()
    $categories["CPU"] = {
            $r = $Global:BenchCpuLastResult
            if (-not $r) { return @(@{Label="Status"; Value="No data - run the CPU benchmark first"}) }
            $rows = @(
                @{Label="Status"; Value=(& $fmtStatus $r)}
                @{Label="Device"; Value=$(if ($r.ContainsKey('DeviceName') -and $r.DeviceName) { $r.DeviceName } else { "Unknown" })}
                @{Label="Run At"; Value=(& $fmtTime $r)}
                @{Label="Test Length"; Value="$($r.DurationSeconds)s (total budget)"}
                @{Label="Logical Threads"; Value=$r.Threads}
                @{Label="Blocks per Pass"; Value=$(if ($r.ContainsKey('Blocks') -and $r.Blocks) { $r.Blocks } else { "N/A" })}
                @{Label="Elapsed"; Value=$(if ($r.ContainsKey('ElapsedSeconds') -and $r.ElapsedSeconds) { "$($r.ElapsedSeconds)s" } else { "N/A" })}
            )
            # Each kernel reports in its own unit (Integer: Mops/s, Float: Mflop/s, Hash: MB/s - not
            # comparable across kernels), so they are listed as separate labeled rows instead of a
            # single Single/Multi pair like the old one-workload version of this benchmark.
            foreach ($type in @("Integer", "Float", "Hash")) {
                $prof = $r[$type]
                if (-not $prof) { continue }
                $rows += @{Label="$type Single-Core"; Value="$($prof.SingleScore) $($prof.Unit)"}
                $rows += @{Label="$type All-Core"; Value="$($prof.MultiScore) $($prof.Unit)"}
                $rows += @{Label="$type MT/ST Ratio"; Value="$($prof.MtStRatio)x"}
            }
            if ($r.ContainsKey('MaxTemp') -and $null -ne $r.MaxTemp) { $rows += @{Label="Max CPU Temp"; Value="$($r.MaxTemp) °C"} }
            if ($r.ContainsKey('MaxPower') -and $null -ne $r.MaxPower) { $rows += @{Label="Max CPU Power"; Value="$($r.MaxPower) W"} }
            if ($r.ContainsKey('MaxClock') -and $null -ne $r.MaxClock) { $rows += @{Label="Max CPU Clock"; Value="$($r.MaxClock) MHz"} }
            if ($r.ContainsKey('MaxLoad') -and $null -ne $r.MaxLoad) { $rows += @{Label="Max CPU Load"; Value="$($r.MaxLoad) %"} }
            $rows
        }.GetNewClosure()
    $categories["GPU"] = {
            $r = $Global:BenchGpuLastResult
            if (-not $r) { return @(@{Label="Status"; Value="No data - run the GPU benchmark first"}) }
            $rows = @(
                @{Label="Status"; Value=(& $fmtStatus $r)}
                @{Label="Device"; Value=$(if ($r.ContainsKey('DeviceName') -and $r.DeviceName) { $r.DeviceName } else { "Unknown" })}
                @{Label="Run At"; Value=(& $fmtTime $r)}
                @{Label="Test Length"; Value="$($r.DurationSeconds)s (total budget)"}
                @{Label="Elapsed"; Value=$(if ($r.ContainsKey('ElapsedSeconds') -and $r.ElapsedSeconds) { "$($r.ElapsedSeconds)s" } else { "N/A" })}
                @{Label="Pipeline"; Value=$r.Mode}
                @{Label="Composite Score"; Value="$($r.CompositeFps) FPS ($($r.CompositeMs) ms/frame)"}
            )
            foreach ($t in @($r.Tests)) {
                if (-not $t) { continue }
                $rows += @{Label="$($t.Name) - $($t.Label)"; Value="$($t.Fps) FPS ($($t.MedianMs) ms/frame, $($t.Blocks) blocks)"}
                $rows += @{Label="$($t.Name) 1st/2nd Half FPS"; Value="$($t.FirstHalfFps) / $($t.SecondHalfFps)"}
            }
            $rows += @{Label="Stability"; Value=$(if ($r.ContainsKey('Throttling')) { if ($r.Throttling) { "Throttling (-$($r.ThrottlePct)%)" } else { "Stable" } } else { "N/A" })}
            if ($r.ContainsKey('MaxTemp') -and $null -ne $r.MaxTemp) { $rows += @{Label="Max GPU Temp"; Value="$($r.MaxTemp) °C"} }
            if ($r.ContainsKey('MaxPower') -and $null -ne $r.MaxPower) { $rows += @{Label="Max GPU Power"; Value="$($r.MaxPower) W"} }
            if ($r.ContainsKey('MaxClock') -and $null -ne $r.MaxClock) { $rows += @{Label="Max GPU Clock"; Value="$($r.MaxClock) MHz"} }
            if ($r.ContainsKey('MaxLoad') -and $null -ne $r.MaxLoad) { $rows += @{Label="Max GPU Load"; Value="$($r.MaxLoad) %"} }
            $rows
        }.GetNewClosure()
    $categories["RAM"] = {
            $r = $Global:BenchRamLastResult
            if (-not $r) { return @(@{Label="Status"; Value="No data - run the RAM benchmark first"}) }
            @(
                @{Label="Status"; Value=(& $fmtStatus $r)}
                @{Label="Device"; Value=$(if ($r.ContainsKey('DeviceName') -and $r.DeviceName) { $r.DeviceName } else { "Unknown" })}
                @{Label="Run At"; Value=(& $fmtTime $r)}
                @{Label="Test Length"; Value="$($r.DurationSeconds)s"}
                @{Label="Buffer Size"; Value="$($r.BufferSizeMB) MB x $($r.Passes) passes"}
                @{Label="Write Avg"; Value="$($r.WriteMBs) MB/s"}
                @{Label="Copy Avg"; Value="$($r.CopyMBs) MB/s"}
                @{Label="Read Avg"; Value=$(if ($r.ContainsKey('ReadMBs') -and $r.ReadMBs) { "$($r.ReadMBs) MB/s" } else { "N/A" })}
                @{Label="Latency"; Value=$(if ($r.ContainsKey('LatencyNs') -and $r.LatencyNs) { "$($r.LatencyNs) ns" } else { "N/A" })}
                @{Label="Multi-Thread Bandwidth"; Value=$(if ($r.ContainsKey('MtBandwidthMBs') -and $r.MtBandwidthMBs) { "$($r.MtBandwidthMBs) MB/s ($($r.MtThreads) threads)" } else { "N/A" })}
            )
        }.GetNewClosure()
    $categories["Disk"] = {
            $r = $Global:BenchDiskLastResult
            if (-not $r) { return @(@{Label="Status"; Value="No data - run the Disk benchmark first"}) }
            @(
                @{Label="Status"; Value=(& $fmtStatus $r)}
                @{Label="Device"; Value=$(if ($r.ContainsKey('DeviceName') -and $r.DeviceName) { $r.DeviceName } else { "Unknown" })}
                @{Label="Run At"; Value=(& $fmtTime $r)}
                @{Label="Test Length"; Value="$($r.DurationSeconds)s"}
                @{Label="Test File Size"; Value="$($r.TotalSizeMB) MB"}
                @{Label="Write Avg"; Value="$($r.WriteMBs) MB/s"}
                @{Label="Read Avg"; Value="$($r.ReadMBs) MB/s"}
                @{Label="4K Random Write"; Value=$(if ($r.ContainsKey('Write4kIops') -and $r.Write4kIops) { "$($r.Write4kIops) IOPS" } else { "N/A" })}
                @{Label="4K Random Read"; Value=$(if ($r.ContainsKey('Read4kIops') -and $r.Read4kIops) { "$($r.Read4kIops) IOPS" } else { "N/A" })}
                @{Label="4K Random Read (Queue Depth)"; Value=$(if ($r.ContainsKey('QdReadIops') -and $r.QdReadIops) { "$($r.QdReadIops) IOPS ($($r.QdThreads) threads)" } else { "N/A" })}
            )
        }.GetNewClosure()

    Show-GuiCategoryDetailPage "Benchmark Results" $categories
}

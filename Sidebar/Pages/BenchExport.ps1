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

    $categories = [ordered]@{
        "All" = {
            $all = @()
            foreach ($name in @("CPU", "GPU", "RAM", "Disk")) {
                $all += @{IsHeader=$true; Label=$name}
                $all += (& $categories[$name])
            }
            $all
        }
        "CPU" = {
            $r = $Global:BenchCpuLastResult
            if (-not $r) { return @(@{Label="Status"; Value="No data - run the CPU benchmark first"}) }
            @(
                @{Label="Status"; Value=(& $fmtStatus $r)}
                @{Label="Run At"; Value=(& $fmtTime $r)}
                @{Label="Test Length"; Value="$($r.DurationSeconds)s"}
                @{Label="Logical Threads"; Value=$r.Threads}
                @{Label="Single-Core Avg"; Value="$($r.SingleScore) it/s"}
                @{Label="Multi-Core Avg"; Value="$($r.MultiScore) it/s"}
            )
        }
        "GPU" = {
            $r = $Global:BenchGpuLastResult
            if (-not $r) { return @(@{Label="Status"; Value="No data - run the GPU benchmark first"}) }
            @(
                @{Label="Status"; Value=(& $fmtStatus $r)}
                @{Label="Run At"; Value=(& $fmtTime $r)}
                @{Label="Test Length"; Value="$($r.DurationSeconds)s"}
                @{Label="Test Type"; Value=$r.Mode}
                @{Label="Average FPS"; Value=$r.AvgFps}
            )
        }
        "RAM" = {
            $r = $Global:BenchRamLastResult
            if (-not $r) { return @(@{Label="Status"; Value="No data - run the RAM benchmark first"}) }
            @(
                @{Label="Status"; Value=(& $fmtStatus $r)}
                @{Label="Run At"; Value=(& $fmtTime $r)}
                @{Label="Test Length"; Value="$($r.DurationSeconds)s"}
                @{Label="Buffer Size"; Value="$($r.BufferSizeMB) MB x $($r.Passes) passes"}
                @{Label="Write Avg"; Value="$($r.WriteMBs) MB/s"}
                @{Label="Copy Avg"; Value="$($r.CopyMBs) MB/s"}
            )
        }
        "Disk" = {
            $r = $Global:BenchDiskLastResult
            if (-not $r) { return @(@{Label="Status"; Value="No data - run the Disk benchmark first"}) }
            @(
                @{Label="Status"; Value=(& $fmtStatus $r)}
                @{Label="Run At"; Value=(& $fmtTime $r)}
                @{Label="Test Length"; Value="$($r.DurationSeconds)s"}
                @{Label="Test File Size"; Value="$($r.TotalSizeMB) MB"}
                @{Label="Write Avg"; Value="$($r.WriteMBs) MB/s"}
                @{Label="Read Avg"; Value="$($r.ReadMBs) MB/s"}
            )
        }
    }

    Show-GuiCategoryDetailPage "Benchmark Results" $categories
}

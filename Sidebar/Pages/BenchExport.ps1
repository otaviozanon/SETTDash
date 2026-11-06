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
            $rows = @(
                @{Label="Status"; Value=(& $fmtStatus $r)}
                @{Label="Device"; Value=$(if ($r.ContainsKey('DeviceName') -and $r.DeviceName) { $r.DeviceName } else { "Unknown" })}
                @{Label="Run At"; Value=(& $fmtTime $r)}
                @{Label="Test Length"; Value="$($r.DurationSeconds)s per profile"}
                @{Label="Logical Threads"; Value=$r.Threads}
            )
            # Each profile reports its own unit (Integer: primes/s, Float/Memory: units/s - not
            # comparable across profiles), so the three are listed as separate labeled rows instead
            # of a single Single/Multi pair like the old one-workload version of this benchmark.
            foreach ($type in @("Integer", "Float", "Memory")) {
                $prof = $r[$type]
                if (-not $prof) { continue }
                $rows += @{Label="$type Single-Core Avg"; Value="$($prof.SingleScore) units/s"}
                $rows += @{Label="$type Multi-Core Avg"; Value="$($prof.MultiScore) units/s"}
                $rows += @{Label="$type MT/ST Ratio"; Value="$($prof.MtStRatio)x"}
            }
            $rows
        }
        "GPU" = {
            $r = $Global:BenchGpuLastResult
            if (-not $r) { return @(@{Label="Status"; Value="No data - run the GPU benchmark first"}) }
            @(
                @{Label="Status"; Value=(& $fmtStatus $r)}
                @{Label="Device"; Value=$(if ($r.ContainsKey('DeviceName') -and $r.DeviceName) { $r.DeviceName } else { "Unknown" })}
                @{Label="Run At"; Value=(& $fmtTime $r)}
                @{Label="Test Length"; Value="$($r.DurationSeconds)s"}
                @{Label="Test Type"; Value=$r.Mode}
                @{Label="Average FPS"; Value=$r.AvgFps}
                @{Label="1st/2nd Half FPS"; Value=$(if ($r.ContainsKey('FirstHalfFps') -and $r.FirstHalfFps) { "$($r.FirstHalfFps) / $($r.SecondHalfFps)" } else { "N/A" })}
                @{Label="Stability"; Value=$(if ($r.ContainsKey('Throttling')) { if ($r.Throttling) { "Throttling (-$($r.ThrottlePct)%)" } else { "Stable" } } else { "N/A" })}
            )
        }
        "RAM" = {
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
        }
        "Disk" = {
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
        }
    }

    Show-GuiCategoryDetailPage "Benchmark Results" $categories
}

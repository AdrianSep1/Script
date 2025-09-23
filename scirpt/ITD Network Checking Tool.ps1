param(
	[switch]$Fast,
	[int]$Retries = 2,
	[int]$BackoffSeconds = 2,
	[int]$WarnThresholdMs = 200,
	[switch]$SaveGraphs
)

# Get current date and time
$currentDateTime = Get-Date -Format "yyyy-MM-dd HH:mm"
Write-Output "$currentDateTime"

# Fast mode settings
$isFastMode = $Fast.IsPresent
$pingCount = if ($isFastMode) { 4 } else { 15 }

$pingable = @()
$notPingable = @()
$latencyResults = @()
$detailedResults = @()

# Helper: create a tiny ASCII sparkline from numeric samples
function Get-Sparkline {
	param([double[]]$Values)
	if (-not $Values -or $Values.Count -eq 0) { return "(no data)" }
	$bars = @('▁','▂','▃','▄','▅','▆','▇','█')
	$min = ($Values | Measure-Object -Minimum).Minimum
	$max = ($Values | Measure-Object -Maximum).Maximum
	if ($min -eq $max) {
		return ($bars[($bars.Count/2)]) * $Values.Count
	}
	$out = ''
	foreach ($v in $Values) {
		$norm = [math]::Round((($v - $min) / ($max - $min)) * ($bars.Count - 1))
		$out += $bars[$norm]
	}
	return $out
}

# Helper: save a simple PNG line chart for a target (requires System.Windows.Forms.DataVisualization)
function Save-GraphImage {
	param(
		[string]$Target,
		[double[]]$Values,
		[string]$OutDir
	)
	try {
		Add-Type -AssemblyName System.Windows.Forms.DataVisualization
		$chart = New-Object System.Windows.Forms.DataVisualization.Charting.Chart
		$chart.Width = 600
		$chart.Height = 200
		$area = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
		$chart.ChartAreas.Add($area)
		$series = New-Object System.Windows.Forms.DataVisualization.Charting.Series
		$series.ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Line
		$series.BorderWidth = 2
		foreach ($val in $Values) { $series.Points.AddY($val) }
		$chart.Series.Add($series)
		if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }
		$file = Join-Path $OutDir ("$($Target -replace '[\\/:*?"<>|]','_')_graph.png")
		$chart.SaveImage($file, 'Png')
	} catch {
		# ignore graphing errors
	}
}

# Targets to test
$targets = @(
	"8.8.8.8",
	"1.1.1.1",
	"192.168.51.1",
	"texxen-voliappe3.spmadridph.com",
	"192.168.51.253"
	"192.168.51.230"
	"192.168.51.231"
	"192.168.51.220"

)



$total = $targets.Count
for ($i = 0; $i -lt $total; $i++) {
	$target = $targets[$i]
	$percentComplete = [int]((($i+1) / $total) * 100)
	Write-Progress -Activity "Pinging targets" -Status "Checking $target ($($i+1)/$total)" -PercentComplete $percentComplete

	$attempt = 0
	$success = $false
	$lastLatency = $null
	while ($attempt -le $Retries -and -not $success) {
		try {
			$pingResults = Test-Connection -ComputerName $target -Count $pingCount -ErrorAction Stop
			$times = @()
			foreach ($r in $pingResults) { if ($r.ResponseTime -ne $null) { $times += [double]$r.ResponseTime } }
			$avgLatency = if ($times.Count -gt 0) { [math]::Round((($times | Measure-Object -Average).Average), 2) } else { $null }
			$pingable += $target
			$latencyResults += "$target - $avgLatency ms"
			$spark = Get-Sparkline -Values $times
			$detailedResults += [pscustomobject]@{ Target = $target; Reachable = $true; AvgMs = $avgLatency; Attempts = $attempt + 1; Timestamp = (Get-Date); Samples = $times; Sparkline = $spark }
			$success = $true
			$lastLatency = $avgLatency
			if ($SaveGraphs) { 
				$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
				$outDir = Join-Path $scriptDir 'graphs'
				Save-GraphImage -Target $target -Values $times -OutDir $outDir
			}
		} catch {
			$attempt++
			if ($attempt -le $Retries) {
				$delay = [math]::Pow($BackoffSeconds, $attempt)
				Start-Sleep -Seconds $delay
			} else {
				$notPingable += $target
				$detailedResults += [pscustomobject]@{ Target = $target; Reachable = $false; AvgMs = $null; Attempts = $attempt; Timestamp = (Get-Date) }
			}
		}
	}
}

Write-Output "`nPingable IPs:"
foreach ($entry in $latencyResults) {
	if ($entry -match '^(.*?) - ([0-9\.]+ ms)$') {
		$target = $matches[1]
		$latency = $matches[2]
		Write-Host -NoNewline "$target - "
		Write-Host $latency -ForegroundColor Green
	} else {
		Write-Host $entry -ForegroundColor Green
	}
}

Write-Output "`nNot Pingable IPs:"
foreach ($ip in $notPingable) {
	Write-Host -NoNewline "$ip - "
	Write-Host "Unreachable" -ForegroundColor Red
}

		# find sparkline in detailedResults
		$detail = $detailedResults | Where-Object { $_.Target -eq $target } | Select-Object -First 1
		$spark = if ($detail) { $detail.Sparkline } else { '' }
		Write-Host -NoNewline "$target - "
		Write-Host $latency -ForegroundColor Green -NoNewline
		if ($spark) { Write-Host "  $spark" }
$reachableCount = ($detailedResults | Where-Object { $_.Reachable }).Count
$unreachableCount = $totalTargets - $reachableCount
$fastest = ($detailedResults | Where-Object { $_.Reachable } | Sort-Object AvgMs | Select-Object -First 1)
$slowest = ($detailedResults | Where-Object { $_.Reachable } | Sort-Object AvgMs -Descending | Select-Object -First 1)

Write-Output "`nSummary:`nTotal: $totalTargets; Reachable: $reachableCount; Unreachable: $unreachableCount"
if ($fastest) { Write-Output "Fastest: $($fastest.Target) - $($fastest.AvgMs) ms" }
if ($slowest) { 
	$slowColor = if ($slowest.AvgMs -ge $WarnThresholdMs) { 'Yellow' } else { 'Green' }
	Write-Host "Slowest: $($slowest.Target) - $($slowest.AvgMs) ms" -ForegroundColor $slowColor
}

Write-Progress -Activity "Pinging targets" -Completed
Write-Output "`nComplete. All targets processed.`n"

Write-Output "`nEnd of Report. Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

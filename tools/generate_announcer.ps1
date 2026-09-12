$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech
$speech = New-Object System.Speech.Synthesis.SpeechSynthesizer
$speech.SelectVoice('Microsoft Zira Desktop')
$speech.Rate = -1
$speech.Volume = 100
$destination = Join-Path $PSScriptRoot '..\assets\audio'
[System.IO.Directory]::CreateDirectory($destination) | Out-Null
$lines = [ordered]@{
    round_one = 'Round one.'
    round_two = 'Round two.'
    final_round = 'Final round.'
    fight = 'Fight!'
    ko = 'K. O!'
    perfect = 'Perfect!'
    counter = 'Counter!'
    guard_break_voice = 'Guard break!'
    final_hit = 'Final hit!'
    player_one_wins = 'Player one wins!'
    player_two_wins = 'Player two wins!'
}
foreach ($entry in $lines.GetEnumerator()) {
    $path = Join-Path $destination ('voice_' + $entry.Key + '.wav')
    $speech.SetOutputToWaveFile($path)
    $speech.Speak($entry.Value)
    $speech.SetOutputToNull()
    Write-Output ('Generated ' + $entry.Key)
}
$speech.Dispose()

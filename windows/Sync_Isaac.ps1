# Isaac Run Roulette - Windows 11 manual sync helper
# Reads a Repentance+ save without modifying it and uploads only a derived JSON summary.
# Uses PowerShell built into Windows 11. GitHub token is encrypted to the Windows user via DPAPI.
param([string]$SavePath = '', [switch]$ResetToken)
$ErrorActionPreference = 'Stop'
$repoOwner = 'breenmee'
$repoName = 'isaac-run-roulette'
$branch = 'main'
$repoFile = 'data/progress.json'
$stateDir = Join-Path $env:LOCALAPPDATA 'IsaacRunRoulette'
$stateFile = Join-Path $stateDir 'settings.json'
$tokenFile = Join-Path $stateDir 'github-token.dpapi'

function To-Path([string]$p) {
  return [Environment]::ExpandEnvironmentVariables($p.Trim('"'))
}
function Find-GameSaves {
  $locations = New-Object 'System.Collections.Generic.List[string]'
  $roots = New-Object 'System.Collections.Generic.List[string]'
  foreach ($root in @((Join-Path ${env:ProgramFiles(x86)} 'Steam'), (Join-Path $env:ProgramFiles 'Steam'))) {
    if ($root -and (Test-Path -LiteralPath $root)) { $roots.Add($root) }
  }
  # Enumerate existing filesystem drives; never assume a D: or E: drive exists.
  foreach ($drive in @(Get-PSDrive -PSProvider FileSystem)) {
    $candidate=Join-Path $drive.Root 'Steam'
    if (Test-Path -LiteralPath $candidate) { $roots.Add($candidate) }
  }
  foreach ($reg in @('HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam')) {
    try {
      $p = Get-ItemProperty -LiteralPath $reg -ErrorAction Stop
      foreach ($k in @('SteamPath','InstallPath')) {if ($p.$k -and (Test-Path $p.$k)) { $roots.Add($p.$k) }}
    } catch {}
  }
  $unique = @($roots | Select-Object -Unique)
  foreach ($root in $unique) {
    $userdata = Join-Path $root 'userdata'
    if (Test-Path $userdata) {
      foreach ($userdir in @(Get-ChildItem -LiteralPath $userdata -Directory -ErrorAction SilentlyContinue)) {
        $p = Join-Path $userdir.FullName '250900\remote\rep+persistentgamedata1.dat'
        if (Test-Path -LiteralPath $p) { $locations.Add($p) }
      }
    }
  }
  $docs = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'My Games\Binding of Isaac Repentance+\persistentgamedata1.dat'
  if (Test-Path -LiteralPath $docs) { $locations.Add($docs) }
  return @($locations | Select-Object -Unique)
}
function Read-Chunks([byte[]]$bytes) {
  if ($bytes.Length -lt 200) { throw 'Save is too short to be a valid Repentance+ file.' }
  $header = [Text.Encoding]::ASCII.GetString($bytes,0,16)
  if (-not $header.StartsWith('ISAACNGSAVE09R')) { throw 'Invalid Isaac save header.' }
  $ms = New-Object IO.MemoryStream(, $bytes)
  $br = New-Object IO.BinaryReader($ms)
  try {
    $ms.Position = 20
    $chunks = @{}
    for ($n=0; $n -lt 11; $n++) {
      if ($ms.Position + 12 -gt $ms.Length) { throw 'Truncated chunk table.' }
      $type = $br.ReadInt32(); $declared = $br.ReadInt32(); $count = $br.ReadInt32()
      if ($type -eq 11) { break } # Bestiary is variable length and not needed.
      if ($type -lt 1 -or $type -gt 10 -or $count -lt 0 -or $count -gt 20000) { throw "Unexpected chunk type/count: $type/$count" }
      $isInt = $type -in @(2,3,8,9)
      $bytesToRead = [long]$count * $(if ($isInt) {4} else {1})
      if ($ms.Position + $bytesToRead -gt $ms.Length) { throw "Truncated chunk $type" }
      if ($isInt) {
        $items = New-Object 'System.Int32[]' $count
        for($j=0;$j -lt $count;$j++) { $items[$j] = $br.ReadInt32() }
      } else { $items = $br.ReadBytes($count) }
      $chunks[$type] = $items
    }
    foreach ($type in @(1,2,7)) {if (-not $chunks.ContainsKey($type)) { throw "Missing required chunk $type" }}
    if ($chunks[1].Length -lt 491 -or $chunks[2].Length -lt 491 -or $chunks[7].Length -lt 46) {
      throw 'Unexpected save format. Make sure this is Repentance+ (not regular Repentance).'
    }
    return $chunks
  } finally { $br.Dispose();$ms.Dispose() }
}
function New-MarkIndices([int]$first,[int]$forgotten,[int]$bethany,[int]$jacob,[int]$tainted) {
  $r = New-Object 'System.Collections.Generic.List[int]'
  for ($i=0; $i -lt 14; $i++) { $r.Add($first+$i) }
  $r.Add($forgotten);$r.Add($bethany);$r.Add($jacob)
  for ($i=0; $i -lt 17; $i++) { $r.Add($tainted+$i) }
  return $r.ToArray()
}
function Build-Progress($chunks,[string]$saveFile) {
  $a=$chunks[1];$events=$chunks[2];$c=$chunks[7]
  $base=@('Isaac','Magdalene','Cain','Judas','???','Eve','Samson','Azazel','Lazarus','Eden','The Lost','Lilith','Keeper','Apollyon','The Forgotten','Bethany','Jacob & Esau')
  $tainted=@('Tainted Isaac','Tainted Magdalene','Tainted Cain','Tainted Judas','Tainted ???','Tainted Eve','Tainted Samson','Tainted Azazel','Tainted Lazarus','Tainted Eden','Tainted Lost','Tainted Lilith','Tainted Keeper','Tainted Apollyon','Tainted Forgotten','Tainted Bethany','Tainted Jacob')
  $baseUnlock=@{'Magdalene'=1;'Cain'=2;'Judas'=3;'???'=32;'Eve'=42;'Samson'=67;'Azazel'=79;'Lazarus'=80;'Eden'=81;'The Lost'=82;'Lilith'=199;'Keeper'=251;'Apollyon'=340;'The Forgotten'=390;'Bethany'=404;'Jacob & Esau'=405}
  $rows=[ordered]@{
    heart    =(New-MarkIndices 27 203 214 215 216)
    isaac    =(New-MarkIndices 41 204 233 234 235)
    satan    =(New-MarkIndices 55 205 252 253 254)
    bossrush =(New-MarkIndices 69 206 271 272 273)
    bluebaby =(New-MarkIndices 83 207 290 291 292)
    lamb     =(New-MarkIndices 97 208 309 310 311)
    megasatan=(New-MarkIndices 116 209 328 329 330)
    greedier =(New-MarkIndices 130 210 347 348 349)
    hush     =(New-MarkIndices 144 211 366 367 368)
    delirium =(New-MarkIndices 173 213 404 405 406)
    mother   = @((423..456))
    beast    = @((457..490))
  }
  $characters = @()
  $totalHard=0;$unlockedChar=0
  for ($i=0;$i -lt 34;$i++) {
    if ($i -lt 17) {
      $name=$base[$i]
      $unlocked=if($name -eq 'Isaac'){$true}else{[bool]$a[$baseUnlock[$name]]}
    } else {
      $name=$tainted[$i-17]
      $unlocked=[bool]$a[474+$i-17]
    }
    if ($unlocked) {$unlockedChar++}
    $goals = @();$completed = 0
    foreach ($mark in $rows.Keys) {
      $index=[int]$rows[$mark][$i]
      $done=($events[$index] -band 2) -ne 0
      if ($done) {$completed++;$totalHard++}
      elseif($mark -ne 'greedier' -or [bool]$a[341]) { $goals += [string]$mark }
    }
    $characters += [ordered]@{id=('char-'+$i);name=$name;unlocked=[bool]$unlocked;hardCompleted=$completed;goals=@($goals)}
  }
  $names=@('Pitch Black','High Brow','Head Trauma','Darkness Falls','The Tank','Solar System','Suicide King','Cat Got Your Tongue','Demo Man','Cursed!','Glass Cannon','When Life Gives You Lemons','Beans!','It''s in the Cards','Slow Roll','Computer Savvy','Waka Waka','The Host','The Family Man','Purist','XXXXXXXXL','SPEED!','Blue Bomber','PAY TO PLAY','Have a Heart','I RULE!','BRAINS!','PRIDE DAY!','Onan''s Streak','The Guardian','Backasswards','Aprils Fool','Pokey Mans','Ultra Hard','Pong','Scat Man','Bloody Mary','Baptism by Fire','Isaac''s Awakening','Seeing Double','Pica Run','Hot Potato','Cantripped!','Red Redemption','DELETE THIS')
  $challenges=@();$completeCount=0
  for($i=1;$i -le 45;$i++) {
    # Challenge availability is tracked by separate secret achievements;
    # defaults are unlocked from the beginning (including Scat Man in Repentance+).
    $default = $i -in @(1,2,3,12,13,14,15,16,17,18,36)
    $unlockId = 0
    if ($i -ge 4 -and $i -le 11) {$unlockId=157+$i-4}
    elseif ($i -eq 19) {$unlockId=165}
    elseif ($i -eq 20) {$unlockId=166}
    elseif ($i -ge 21 -and $i -le 30) {$unlockId=265+$i-21}
    elseif ($i -ge 31 -and $i -le 35) {$unlockId=277+$i-31}
    elseif ($i -ge 37 -and $i -le 45) {$unlockId=508+$i-37}
    $completed=[bool]$c[$i]
    if($completed){$completeCount++}
    $available = $default -or $completed -or ($unlockId -gt 0 -and [bool]$a[$unlockId])
    $challenges += [ordered]@{id=[string]$i;name=$names[$i-1];unlocked=[bool]$available;completed=$completed}
  }
  $achievementCount=0
  for($i=1;$i -lt [Math]::Min($a.Length,642);$i++) {if($a[$i] -ne 0){$achievementCount++}}
  return [ordered]@{
    schemaVersion=1
    exact=$true
    source='repentance-plus-persistent-save'
    updatedAt=[DateTime]::UtcNow.ToString('o')
    saveModifiedAt=(Get-Item -LiteralPath $saveFile).LastWriteTimeUtc.ToString('o')
    saveSlot=1
    achievementsUnlocked=$achievementCount
    achievementsTotal=641
    hardMarksCompleted=$totalHard
    hardMarksTotal=408
    charactersUnlocked=$unlockedChar
    challengesCompleted=$completeCount
    challengesTotal=45
    characters=$characters
    challenges=$challenges
  }
}
function Get-Token {
  New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
  if ($ResetToken -and (Test-Path $tokenFile)) { Remove-Item -LiteralPath $tokenFile -Force }
  if (-not (Test-Path $tokenFile)) {
    Write-Host "First-time setup: GitHub needs a fine-grained token, limited to '$repoName' with Contents: Read and write." -ForegroundColor Yellow
    Write-Host 'Create one at https://github.com/settings/personal-access-tokens/new and paste it below.'
    Write-Host "Never put the token into the GitHub repository or send it in chat."
    $secure=Read-Host 'Paste GitHub fine-grained token' -AsSecureString
    if($secure.Length -eq 0){throw 'No token supplied'}
    $secure | ConvertFrom-SecureString | Set-Content -LiteralPath $tokenFile -Encoding UTF8
    Write-Host "Token saved encrypted for your Windows account ($tokenFile)." -ForegroundColor Green
  }
  $encrypted=Get-Content -LiteralPath $tokenFile -Raw
  $secureText=$encrypted.Trim() | ConvertTo-SecureString
  $ptr=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureText)
  try{return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)}
  finally {[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)}
}
function Publish-Json([string]$json,[string]$token) {
  $api="https://api.github.com/repos/$repoOwner/$repoName/contents/$repoFile"
  $headers=@{'Authorization'="Bearer $token";'Accept'='application/vnd.github+json';'User-Agent'='IsaacRunRouletteSync';'X-GitHub-Api-Version'='2022-11-28'}
  $sha=$null
  try {
    $old=Invoke-RestMethod -Uri "$api`?ref=$branch" -Headers $headers -Method Get
    $sha=$old.sha
  } catch {
    $code=$null
    if ($_.Exception.Response) {$code=[int]$_.Exception.Response.StatusCode}
    if ($code -ne 404) {throw "GitHub access failed ($code). Check the token's Contents permission and repository selection. $($_.Exception.Message)"}
  }
  $payload=@{message='Sync Isaac progress';branch=$branch;content=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json))}
  if ($sha) {$payload['sha']=$sha}
  $body=$payload | ConvertTo-Json -Depth 5 -Compress
  try {
    $null=Invoke-RestMethod -Uri $api -Headers $headers -Method Put -Body $body -ContentType 'application/json; charset=utf-8'
  } catch {
    throw "GitHub update failed. No files were changed on your PC. $($_.Exception.Message)"
  }
}
try {
  Write-Host ''
  Write-Host '=== Isaac Run Roulette - Steam Save Sync ===' -ForegroundColor Cyan
  if (-not $SavePath -and (Test-Path $stateFile)) {
    try { $saved=Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json; if ($saved.savePath -and (Test-Path -LiteralPath $saved.savePath)) {$SavePath=$saved.savePath} } catch {}
  }
  if (-not $SavePath) {
    $found=@(Find-GameSaves)
    if ($found.Count -eq 1) { $SavePath=$found[0] }
    elseif($found.Count -gt 1) {
      Write-Host 'I found multiple possible slot-1 saves:'
      for($i=0;$i -lt $found.Count;$i++){Write-Host ('[{0}] {1} (modified {2})' -f ($i+1),$found[$i],(Get-Item -LiteralPath $found[$i]).LastWriteTime)}
      $answer=Read-Host 'Select the correct number'
      $idx=0
      if(-not [int]::TryParse($answer,[ref]$idx) -or $idx -lt 1 -or $idx -gt $found.Count){throw 'Invalid selection'}
      $SavePath=$found[$idx-1]
    }
  }
  if (-not $SavePath -or -not (Test-Path -LiteralPath $SavePath)) {
    $SavePath=Read-Host 'Paste the FULL path to rep+persistentgamedata1.dat (from your Save Finder)'
    $SavePath=To-Path $SavePath
  }
  if (-not (Test-Path -LiteralPath $SavePath -PathType Leaf)) {throw "File not found: $SavePath"}
  if ([IO.Path]::GetFileName($SavePath) -notin @('rep+persistentgamedata1.dat','persistentgamedata1.dat')) {throw 'Please select the Repentance+ persistent save for slot 1, not gamestate or regular Repentance.'}
  New-Item -Path $stateDir -ItemType Directory -Force | Out-Null
  @{savePath=$SavePath}|ConvertTo-Json|Set-Content -LiteralPath $stateFile -Encoding UTF8
  Write-Host "Reading: $SavePath"
  $file=Get-Item -LiteralPath $SavePath
  Write-Host ('Save modified: ' + $file.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
  $parsed=Build-Progress (Read-Chunks ([IO.File]::ReadAllBytes($SavePath))) $SavePath
  $eligibleChars=@($parsed.characters|Where-Object{$_.unlocked -and $_.goals.Count -gt 0}).Count
  $eligibleChallenges=@($parsed.challenges|Where-Object{$_.unlocked -and -not $_.completed}).Count
  Write-Host ("Marks: {0}/408 | Characters to do: {1} | Available challenges: {2}" -f $parsed.hardMarksCompleted,$eligibleChars,$eligibleChallenges) -ForegroundColor Green
  Write-Host 'Only a progress summary will be published. Your raw .dat file stays on this PC.'
  $ok=Read-Host 'Publish this progress to the public GitHub Pages repo? (Y/N)'
  if ($ok -notin @('y','Y','yes','YES')) { Write-Host 'Cancelled. Nothing was uploaded.'; exit 0 }
  $token=Get-Token
  $json=$parsed|ConvertTo-Json -Depth 20
  Publish-Json $json $token
  Write-Host 'SUCCESS! Progress published.' -ForegroundColor Green
  Write-Host 'Your site: https://breenmee.github.io/isaac-run-roulette/'
  Write-Host 'Wait for GitHub Pages to deploy, then press Refresh Progress in the roulette.'
} catch {
  Write-Host ''
  Write-Host 'ERROR:' -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  Write-Host 'Your Isaac save was not changed.'
  exit 1
}

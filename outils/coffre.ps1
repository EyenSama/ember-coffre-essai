<#
  Coffre.ps1 — fabrique un coffre Obsidian personnalise, puis le tient a jour par git.

  Rien a installer : git et Windows suffisent. Le script interroge le depot public du
  modele (aucun identifiant demande), clone s'il faut, ou fait un git pull si le coffre
  existe deja. Ta personnalisation — teinte, dossiers — est ensuite reappliquee : elle
  vit chez toi et ne salit jamais le depot.

  Le plus simple : coller dans un terminal la ligne qui telecharge ce fichier et l'execute.
#>

$ErrorActionPreference = 'Continue'

$Modele = 'https://github.com/EyenSama/ember-coffre-essai.git'
$UrlScript = 'https://cdn.jsdelivr.net/gh/EyenSama/ember-coffre-essai@main/outils/coffre.ps1'
$ZonesDefaut = '00-INDEX, 10-Inbox, 15-Cartes, 20-Notes, 30-Projets, 40-Journal, 50-Ressources'
$CouleursZones = @('--e-bleu','--e-cyan','--e-peche','--e-vert','--e-lavande','--e-gris','--e-texte-structure')
$dossierJournal = [Environment]::GetFolderPath('MyDocuments')
if ([string]::IsNullOrWhiteSpace($dossierJournal)) { $dossierJournal = (Get-Location).Path }
$Journal = Join-Path $dossierJournal 'coffre-journal.txt'
$Enc = New-Object System.Text.UTF8Encoding($false)

function Note($texte, $couleur) {
    if (-not $couleur) { $couleur = 'White' }
    Write-Host $texte -ForegroundColor $couleur
    try { Add-Content -Path $Journal -Value $texte -Encoding UTF8 } catch { }
}

function LancerGit($dossier, $arguments) {
    $sortie = & git -C $dossier @arguments 2>&1
    $code = $LASTEXITCODE
    if ($sortie) { foreach ($l in $sortie) { Note ('    ' + $l) 'DarkGray' } }
    return $code
}

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

Note ''
Note '  Deploiement d un coffre Obsidian' 'Cyan'
Note '  ---------------------------------'
Note ('  Journal : {0}' -f $Journal) 'DarkGray'
Note ''

try {
    $DefautBase = (Get-Location).Path
    foreach ($systeme in @($env:SystemRoot, $env:ProgramFiles)) {
        if ($systeme -and $DefautBase.StartsWith($systeme)) {
            $DefautBase = [Environment]::GetFolderPath('MyDocuments')
        }
    }
    $reponseBase = Read-Host ('  Dossier ou poser le coffre (Entree = {0})' -f $DefautBase)
    $base = $DefautBase
    if (-not [string]::IsNullOrWhiteSpace($reponseBase)) { $base = $reponseBase.Trim().Trim([char]34) }
    if (-not (Test-Path $base)) { throw ('Ce dossier n existe pas : {0}' -f $base) }

    $reponseNom = Read-Host '  Nom du coffre (Entree = Coffre essai)'
    $nom = 'Coffre essai'
    if (-not [string]::IsNullOrWhiteSpace($reponseNom)) { $nom = $reponseNom.Trim() }
    $cible = Join-Path $base $nom

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw 'git est introuvable. Installer Git pour Windows depuis git-scm.com, puis relancer.'
    }

    Note ''
    if (Test-Path (Join-Path $cible '.git')) {
        Note '  Le coffre existe deja : mise a jour par git.'
        LancerGit $cible @('fetch','--quiet') | Out-Null
        LancerGit $cible @('checkout','--','.') | Out-Null
        $code = LancerGit $cible @('pull','--quiet')
        if ($code -ne 0) { throw ('La mise a jour a echoue (code {0}). Rien n a ete modifie.' -f $code) }
    } else {
        if (Test-Path $cible) { throw ('Ce dossier existe et n est pas un coffre : {0}' -f $cible) }
        Note '  Recuperation du modele depuis git...'
        $code = LancerGit (Get-Location).Path @('clone','--quiet',$Modele,$cible)
        if ($code -ne 0) { throw ('Le clone a echoue (code {0}).' -f $code) }
    }

    $snippets = Join-Path $cible '.obsidian' 'snippets'
    if (-not (Test-Path $snippets)) { throw 'Le modele est incomplet : dossier des extraits introuvable.' }

    $fichiers = Get-ChildItem $snippets -Filter 'teinte-*.css' | Sort-Object Name
    $noms = @()
    $accents = @()
    foreach ($f in $fichiers) {
        $accent = '?'
        $trouve = Select-String -Path $f.FullName -Pattern '--e-bleu:\s*(#[0-9A-Fa-f]{6})' -ErrorAction SilentlyContinue
        if ($trouve -and $trouve.Matches.Count -gt 0) { $accent = $trouve.Matches[0].Groups[1].Value }
        $noms += ($f.BaseName -replace '^teinte-','')
        $accents += $accent
    }
    if ($noms.Count -eq 0) { throw 'Aucune teinte trouvee dans le modele.' }

    Note ''
    Note '  Teintes disponibles' 'Cyan'
    for ($i = 0; $i -lt $noms.Count; $i++) {
        $numero = $i + 1
        Note ('    {0,2}. {1,-14} accent {2}' -f $numero, $noms[$i], $accents[$i])
    }
    $defautTeinte = 1
    for ($i = 0; $i -lt $noms.Count; $i++) { if ($noms[$i] -eq 'bleu') { $defautTeinte = $i + 1 } }
    $reponseTeinte = Read-Host ('  Numero de la teinte (Entree = {0})' -f $defautTeinte)
    $choix = $defautTeinte
    if (-not [string]::IsNullOrWhiteSpace($reponseTeinte)) {
        $saisie = 0
        if (-not [int]::TryParse($reponseTeinte.Trim(), [ref]$saisie)) { throw 'Numero de teinte invalide.' }
        if ($saisie -lt 1 -or $saisie -gt $noms.Count) { throw 'Numero de teinte hors liste.' }
        $choix = $saisie
    }
    $teinte = $noms[$choix - 1]
    $accentTeinte = $accents[$choix - 1]

    Note ''
    $reponseZones = Read-Host '  Dossiers, separes par des virgules (Entree = les dossiers par defaut)'
    $zonesSaisie = $ZonesDefaut
    if (-not [string]::IsNullOrWhiteSpace($reponseZones)) { $zonesSaisie = $reponseZones }
    $zones = @()
    foreach ($z in ($zonesSaisie -split ',')) {
        $propre = $z.Trim()
        if ($propre -eq '') { continue }
        if ($propre -notmatch '^[A-Za-z0-9][A-Za-z0-9 ._-]{0,40}$') { throw ('Dossier invalide : {0}' -f $propre) }
        $zones += $propre
    }
    if ($zones.Count -eq 0) { throw 'Aucun dossier valide.' }
    $zonesTexte = ($zones -join ', ')

    # une seule teinte reste
    foreach ($f in $fichiers) {
        if ($f.BaseName -ne ('teinte-' + $teinte)) { Remove-Item $f.FullName -Force }
    }
    $fTeinte = Join-Path $snippets ('teinte-' + $teinte + '.css')

    # les couleurs de dossiers, posees deux fois : la ligne et son texte
    $bloc = "`r`n/* ---- zones de ce coffre ---- */`r`n"
    for ($i = 0; $i -lt $zones.Count; $i++) {
        $couleur = $CouleursZones[$i % $CouleursZones.Count]
        $cheminZone = $zones[$i].TrimEnd('/')
        $bloc += 'body .nav-folder-title[data-path="' + $cheminZone + '"] { color: var(' + $couleur + ') !important; }' + "`r`n"
        $bloc += 'body .nav-folder-title[data-path="' + $cheminZone + '"] .nav-folder-title-content { color: var(' + $couleur + ') !important; }' + "`r`n"
    }
    $texteTeinte = [System.IO.File]::ReadAllText($fTeinte, [System.Text.Encoding]::UTF8)
    $gardees = @()
    foreach ($l in ($texteTeinte -split "`n")) {
        if ($l -notmatch 'nav-folder-title\[data-path=') { $gardees += $l }
    }
    [System.IO.File]::WriteAllText($fTeinte, (($gardees -join "`n").TrimEnd() + "`r`n" + $bloc), $Enc)

    # les reglages
    $fApp = Join-Path $cible '.obsidian' 'appearance.json'
    $app = [System.IO.File]::ReadAllText($fApp, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    $app.cssTheme = 'Border'
    $app.accentColor = $accentTeinte
    $app.enabledCssSnippets = @('socle', ('teinte-' + $teinte))
    [System.IO.File]::WriteAllText($fApp, ($app | ConvertTo-Json -Depth 5), $Enc)

    $fApp2 = Join-Path $cible '.obsidian' 'app.json'
    $app2 = [System.IO.File]::ReadAllText($fApp2, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    $app2.showInlineTitle = $false
    [System.IO.File]::WriteAllText($fApp2, ($app2 | ConvertTo-Json -Depth 5), $Enc)

    # la structure
    foreach ($d in (Get-ChildItem $cible -Directory)) {
        if ($d.Name -notmatch '^\.') { Remove-Item $d.FullName -Recurse -Force }
    }
    foreach ($z in $zones) {
        if ($z -ne '00-INDEX') { New-Item -ItemType Directory -Path (Join-Path $cible $z.TrimEnd('/')) -Force | Out-Null }
    }
    $texteIndex = "# Index`r`n`r`nLa porte du coffre " + $nom + ". Elle ne mene qu a l essentiel.`r`n`r`n- [[Bienvenue]]`r`n"
    [System.IO.File]::WriteAllText((Join-Path $cible '00-INDEX.md'), $texteIndex, $Enc)

    $premiere = ''
    foreach ($z in $zones) { if ($z -ne '00-INDEX') { $premiere = $z; break } }
    if ($premiere -ne '') {
        $dossierPremier = Join-Path $cible $premiere
        New-Item -ItemType Directory -Path $dossierPremier -Force | Out-Null
        $texteBienvenue = "# Bienvenue`r`n`r`n#type/note`r`n`r`nLe coffre " + $nom + " est pret. Teinte : " + $teinte + ".`r`n"
        [System.IO.File]::WriteAllText((Join-Path $dossierPremier 'Bienvenue.md'), $texteBienvenue, $Enc)
    }

    foreach ($doc in @('MODE-D-EMPLOI.md','LICENCE-TIERS.md')) {
        $cheminDoc = Join-Path $cible $doc
        if (Test-Path $cheminDoc) { Remove-Item $cheminDoc -Force }
    }

    # une copie du script dans le coffre : le relancer suffira a le mettre a jour
    $copie = Join-Path $cible 'Mettre a jour le coffre.ps1'
    try {
        if ($PSCommandPath -and (Test-Path $PSCommandPath)) {
            Copy-Item $PSCommandPath $copie -Force
        } else {
            Invoke-WebRequest -Uri $UrlScript -OutFile $copie -UseBasicParsing
        }
        Note '    Une copie du script est dans le coffre : Mettre a jour le coffre.ps1'
    } catch { Note '    La copie du script dans le coffre n a pas pu etre faite.' 'DarkGray' }

    Note ''
    Note '  C est pret.' 'Green'
    Note ('    Coffre   : {0}' -f $cible)
    Note ('    Teinte   : {0}  {1}' -f $teinte, $accentTeinte)
    Note ('    Dossiers : {0}' -f $zonesTexte)
    Note ''
    Note '  Dans Obsidian : ouvrir un dossier comme coffre, puis choisir ce dossier.'
    Note '  Relancer ce script quand tu veux : git pull, puis ta teinte reappliquee.'
}
catch {
    Note ''
    Note ('  ECHEC : {0}' -f $_.Exception.Message) 'Red'
    Note '  Rien n a ete laisse a moitie fait. Reessaie, ou envoie-moi le journal.' 'Red'
}
finally {
    Note ''
    Read-Host '  Appuie sur Entree pour fermer'
}

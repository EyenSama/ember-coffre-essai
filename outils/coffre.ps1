<#
  Coffre.ps1 — fabrique un coffre Obsidian personnalisé, puis le tient à jour par git.

  Rien à installer : git et Windows suffisent. Le script interroge le dépôt public du
  modèle (aucun identifiant demandé), clone s'il faut, ou fait un git pull si le coffre
  existe déjà. Ta personnalisation (teinte, dossiers) est ensuite réappliquée : elle
  vit chez toi et ne salit jamais le dépôt.

  Le plus simple : double-clique sur Coffre.bat, dans le même dossier que ce fichier.
#>

$ErrorActionPreference = 'Continue'

# le dépôt public : clonable sans identifiant, même contenu que le modèle
$Modele = 'https://github.com/EyenSama/ember-coffre-essai.git'
$ZonesDefaut = '00-INDEX, 10-Inbox, 15-Cartes, 20-Notes, 30-Projets, 40-Journal, 50-Ressources'
$CouleursZones = @('--e-bleu','--e-cyan','--e-peche','--e-vert','--e-lavande','--e-gris','--e-texte-structure')
$Journal = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'coffre-journal.txt'

function Note($texte, $couleur = 'White') {
    Write-Host $texte -ForegroundColor $couleur
    try { Add-Content -Path $Journal -Value $texte -Encoding UTF8 } catch { }
}

function Git($arguments, $dossier) {
    # la sortie de git est capturée puis écrite : plus rien ne peut se perdre dans le vide
    $sortie = & git -C $dossier @arguments 2>&1
    $code = $LASTEXITCODE
    if ($sortie) { Note ("    " + ($sortie -join "`r`n    ")) 'DarkGray' }
    return $code
}

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

Note ''
Note '  Déploiement d''un coffre Obsidian' 'Cyan'
Note '  ---------------------------------'
Note ("  Journal : " + $Journal) 'DarkGray'
Note ''

try {
    $DefautBase = (Get-Location).Path
    $interdit = @($env:SystemRoot, $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:USERPROFILE) | Where-Object { $_ }
    foreach ($i in $interdit) { if ($DefautBase -like ($i + '*')) { $DefautBase = [Environment]::GetFolderPath('MyDocuments'); break } }
    $base = Read-Host "  Dossier où poser le coffre (Entrée = $DefautBase)"
    if ([string]::IsNullOrWhiteSpace($base)) { $base = $DefautBase }
    if (-not (Test-Path $base)) { throw "Ce dossier n'existe pas : $base" }

    $nom = Read-Host "  Nom du coffre (Entrée = Coffre essai)"
    if ([string]::IsNullOrWhiteSpace($nom)) { $nom = 'Coffre essai' }
    $nom = $nom.Trim()
    $cible = Join-Path $base $nom

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "git est introuvable. Installe Git pour Windows (git-scm.com), puis relance."
    }

    Note ''
    if (Test-Path (Join-Path $cible '.git')) {
        Note '  Le coffre existe déjà : mise à jour par git.'
        $code = Git @('fetch','--quiet') $cible
        Git @('checkout','--','.') $cible | Out-Null   # la personnalisation locale sera réappliquée
        $code = Git @('pull','--quiet') $cible
        if ($code -ne 0) { throw "La mise à jour a échoué (code $code). Rien n'a été modifié." }
    } else {
        if (Test-Path $cible) { throw "Ce dossier existe et n'est pas un coffre : $cible" }
        Note '  Récupération du modèle depuis git...'
        $code = Git @('clone','--quiet',$Modele,$cible) (Get-Location).Path
        if ($code -ne 0) { throw "Le clone a échoué (code $code)." }
    }

    $snippets = Join-Path $cible '.obsidian\snippets'
    if (-not (Test-Path $snippets)) { throw 'Le modèle est incomplet : dossier des extraits introuvable.' }

    # --- les teintes disponibles, lues dans le modèle ---
    $fichiers = Get-ChildItem $snippets -Filter 'teinte-*.css' | Sort-Object Name
    $teintes = @()
    foreach ($f in $fichiers) {
        $accent = $null
        $m = Select-String -Path $f.FullName -Pattern '--e-bleu:\s*(#[0-9A-Fa-f]{6})' -ErrorAction SilentlyContinue
        if ($m -and $m.Matches.Count -gt 0) { $accent = $m.Matches[0].Groups[1].Value }
        $teintes += [pscustomobject]@{ Nom = ($f.BaseName -replace '^teinte-',''); Accent = $accent }
    }
    if ($teintes.Count -eq 0) { throw 'Aucune teinte trouvée dans le modèle.' }

    Note ''
    Note '  Teintes disponibles' 'Cyan'
    for ($i = 0; $i -lt $teintes.Count; $i++) {
        Note ("    {0,2}. {1,-14} accent {2}" -f ($i + 1), $teintes[$i].Nom, $teintes[$i].Accent)
    }
    $defautTeinte = 1
    for ($i = 0; $i -lt $teintes.Count; $i++) { if ($teintes[$i].Nom -eq 'bleu') { $defautTeinte = $i + 1 } }
    $saisie = Read-Host "  Numéro de la teinte (Entrée = $defautTeinte)"
    $numero = $defautTeinte
    if (-not [string]::IsNullOrWhiteSpace($saisie)) {
        if (-not [int]::TryParse($saisie, [ref]$numero) -or $numero -lt 1 -or $numero -gt $teintes.Count) {
            throw 'Numéro de teinte invalide.'
        }
    }
    $teinte = $teintes[$numero - 1]

    Note ''
    $zonesSaisie = Read-Host "  Dossiers, séparés par des virgules (Entrée = les dossiers par défaut)"
    if ([string]::IsNullOrWhiteSpace($zonesSaisie)) { $zonesSaisie = $ZonesDefaut }
    $zones = @()
    foreach ($z in ($zonesSaisie -split ',')) {
        $propre = $z.Trim()
        if ($propre -eq '') { continue }
        if ($propre -notmatch '^[A-Za-z0-9][A-Za-z0-9 ._-]{0,40}$') { throw "Dossier invalide : $propre" }
        $zones += $propre
    }
    if ($zones.Count -eq 0) { throw 'Aucun dossier valide.' }

    # --- appliquer la teinte : une seule reste ---
    foreach ($f in $fichiers) { if ($f.BaseName -ne ('teinte-' + $teinte.Nom)) { Remove-Item $f.FullName -Force } }
    $fTeinte = Join-Path $snippets ('teinte-' + $teinte.Nom + '.css')

    $bloc = "`r`n/* ---- zones de ce coffre ---- */`r`n"
    for ($i = 0; $i -lt $zones.Count; $i++) {
        $couleur = $CouleursZones[$i % $CouleursZones.Count]
        $cheminZone = $zones[$i].TrimEnd('/')
        $bloc += "body .nav-folder-title[data-path=""$cheminZone""] { color: var($couleur) !important; }`r`n"
        $bloc += "body .nav-folder-title[data-path=""$cheminZone""] .nav-folder-title-content { color: var($couleur) !important; }`r`n"
    }
    $enc = New-Object System.Text.UTF8Encoding($false)
    $texteTeinte = [System.IO.File]::ReadAllText($fTeinte, [System.Text.Encoding]::UTF8)
    $texteTeinte = (($texteTeinte -split "`n") | Where-Object { $_ -notmatch 'nav-folder-title\[data-path=' }) -join "`n"
    [System.IO.File]::WriteAllText($fTeinte, $texteTeinte.TrimEnd() + "`r`n" + $bloc, $enc)

    # --- les réglages ---
    $fApp = Join-Path $cible '.obsidian\appearance.json'
    $app = [System.IO.File]::ReadAllText($fApp, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    $app.cssTheme = 'Border'
    $app.accentColor = $teinte.Accent
    $app.enabledCssSnippets = @('socle', ('teinte-' + $teinte.Nom))
    [System.IO.File]::WriteAllText($fApp, ($app | ConvertTo-Json -Depth 5), $enc)

    $fApp2 = Join-Path $cible '.obsidian\app.json'
    $app2 = [System.IO.File]::ReadAllText($fApp2, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    $app2.showInlineTitle = $false
    [System.IO.File]::WriteAllText($fApp2, ($app2 | ConvertTo-Json -Depth 5), $enc)

    # --- la structure ---
    Get-ChildItem $cible -Directory | Where-Object { $_.Name -notmatch '^\.' } | ForEach-Object { Remove-Item $_.FullName -Recurse -Force }
    foreach ($z in $zones) { if ($z -ne '00-INDEX') { New-Item -ItemType Directory -Path (Join-Path $cible $z.TrimEnd('/')) -Force | Out-Null } }
    [System.IO.File]::WriteAllText((Join-Path $cible '00-INDEX.md'),
        "# Index`r`n`r`nLa porte du coffre « $nom ». Elle ne mène qu'à l'essentiel.`r`n`r`n- [[Bienvenue]]`r`n", $enc)
    $premiere = ($zones | Where-Object { $_ -ne '00-INDEX' } | Select-Object -First 1)
    if ($premiere) {
        New-Item -ItemType Directory -Path (Join-Path $cible $premiere) -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $cible "$premiere\Bienvenue.md"),
            "# Bienvenue`r`n`r`n#type/note`r`n`r`nLe coffre « $nom » est prêt. Teinte : $($teinte.Nom).`r`n", $enc)
    }

    foreach ($doc in @('MODE-D-EMPLOI.md','LICENCE-TIERS.md')) {
        $c = Join-Path $cible $doc
        if (Test-Path $c) { Remove-Item $c -Force }
    }
    # on laisse le script dans le coffre : le relancer suffira à le remettre à jour
    try { Copy-Item $PSCommandPath (Join-Path $cible 'Mettre a jour le coffre.ps1') -Force } catch { }

    Note ''
    Note '  C''est prêt.' 'Green'
    Note "    Coffre   : $cible"
    Note "    Teinte   : $($teinte.Nom) ($($teinte.Accent))"
    Note "    Dossiers : $($zones -join ', ')"
    Note ''
    Note '  Dans Obsidian : « Ouvrir un dossier comme coffre », puis choisis ce dossier.'
    Note '  Relance ce script quand tu veux : git pull, puis ta teinte réappliquée.'
}
catch {
    Note ''
    Note ('  ÉCHEC : ' + $_.Exception.Message) 'Red'
    Note '  Rien n''a été laissé à moitié fait : réessaie ou envoie-moi le journal.' 'Red'
}
finally {
    Note ''
    Read-Host '  Appuie sur Entrée pour fermer'
}

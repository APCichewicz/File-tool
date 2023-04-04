Add-Type -AssemblyName PresentationFramework
$dataloc = (Get-ChildItem Env:\cwdata).value

if (-not (test-path $dataloc)) {Exit}

$root = $PSScriptRoot
Set-Location $root

# Load XAML
[xml]$xaml = Get-Content -Path "$($root)\findBinder.xaml"
$reader = (New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Create directories if not exist
$directories = @("\binders", "\binders\backups")

foreach ($dir in $directories) {
  $filePath = Join-Path $root $dir
  if (-not (Test-Path $filePath)) {
    New-Item -ItemType Directory -Path $filePath
  }
}

# Get elements from XAML
$xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object {
    $name = $_.Name
    $element = $window.FindName($name)
    Set-Variable -Name $name -Value $element -Scope Script
}


# Function to display error messages in a popup
function Show-ErrorPopup($message) {
    $wshell = New-Object -ComObject Wscript.Shell
    $wshell.Popup("Error: $message", 0, "Error", 16)
}
function Show-Popup($message) {
    $wshell = New-Object -ComObject Wscript.Shell
    $wshell.Popup("$message", 0, "Confirmation", 16)
}
# Event handlers
$Search.Add_Click({
    try {
        if ($PathTextBox.Text.Length -ge 1) {
            $listview.Items.Clear()
            Select-String -Path "output.txt" -Pattern $PathTextBox.Text -ErrorAction SilentlyContinue | Select-Object -first 10 | ForEach-Object {
                $listview.Items.Add((($_ -split ":")[-1]))
            }
        }
    } catch {
        Show-ErrorPopup $_
    }
})

# Move button event handler
$moveButton.Add_Click({
    try {
        $selectedItem = $listview.SelectedItem
        $objShell = New-Object -ComObject 'Shell.Application'
        $backups = $objShell.NameSpace((join-path $root "binders\backups"))
        $backups.CopyHere($selectedItem)
        $newlocation = $objShell.NameSpace($locationList.SelectedItem)
        $newlocation.MoveHere($selectedItem)
    } catch {
        Show-ErrorPopup $_
    }
})

# Open button event handler
$openButton.Add_Click({
    try {
        explorer.exe "$($listview.SelectedItem)"
    } catch {
        Show-ErrorPopup $_
    }
})

# Update button event handler
$updateButton.Add_Click({

   Get-ChildItem -Recurse -Depth 1 -Path $dataloc -ErrorAction SilentlyContinue | select -ExpandProperty fullname | Out-File -FilePath output.txt -Encoding utf8
   show-popup "Binder list updated"
   
})

# Copy button event handler
$copyButton.Add_Click({
    if ($listview.SelectedItem -ne $null -and (test-path $dataloc)) {
        try {
            $selectedItem = $listview.SelectedItem
            $objShell = New-Object -ComObject 'Shell.Application'
            $objFolder = $objShell.NameSpace((join-path $root "\binders"))
            $objFolder2 = $objShell.NameSpace((join-path $root "\binders\backups"))
            $objFolder.CopyHere($selectedItem)
            $objFolder2.CopyHere($selectedItem)
        } catch {
            Show-ErrorPopup $_
        }
    } else {
        if ($listview.SelectedItem -eq $null) {
            Show-ErrorPopup "You Must make a selection"
        }
        if (-not (test-path $dataloc)) {
            Show-ErrorPopup "You must be connected to the vpn"
        }
    }
})

# Clip button event handler
$clipButton.Add_Click({
    try {
        Set-Clipboard $listview.SelectedItem.split("\")[-1]
    } catch {
        Show-ErrorPopup $_
    }
})
# populate the location list
try {
    $locations = Get-ChildItem -Path $dataloc -ErrorAction Stop | Where-Object name -match '^[0-9].*' | Select-Object -ExpandProperty FullName 
    $locationList.ItemsSource = $locations
}
 catch {
    $_ | Out-Null
    Show-ErrorPopup "You Must be Connected to the vpn"
 }


# Show window
$window.ShowDialog() | Out-Null
read-host "enter to exit"

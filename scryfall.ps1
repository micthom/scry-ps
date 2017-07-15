function Get-MtgCard
{
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
            [string]$Name,
        [Parameter(Position=1)]
            [ValidateSet("Text", "Web", "Image", "Json")]
            [string]$Output="Text"
    )    

    # First, check to see if the name input is a number, if it is then the user
    # is asking for a card by quick access from a previous query, so we find the name
    # that corresponds with the number and use that
    $nameAsInt = $Name -as [int]
    if ($nameAsInt -ne $null)
    {
        $index = $nameAsInt - 1;
        if ($index -ge 0 -and $index -lt $Global:lastCards.Count)
        {
            $Name = $Global:lastCards[$nameAsInt-1]
        }
        else 
        {
            throw [ArgumentOutOfRangeException] "Name"    
        }

    }

    $name = [uri]::EscapeUriString($name);

    $api = "https://api.scryfall.com/cards"
    $card = $null
    $cardList = $null;
    $webException = $null;
    
    # first, see if we can find the exact name
    $exact = "${api}/named?exact=${name}&format=json"
    try { $card = Invoke-RestMethod $exact } catch { $webException = $_.Exception }
    
    # if we didn't find the name during the exact name, try fuzzy name query
    if ($card -eq $null)
    {
        $fuzzy = "${api}/named?fuzzy=${name}&format=json"
        try { $card = Invoke-RestMethod $fuzzy } catch { $webException = $_.Exception }
    }

    # if we still didn't find it, do a full search (this will get us a list of possibilities)
    if ($card -eq $null)
    {
        $search = "${api}/search?q=${name}"
        try { $cardList = Invoke-RestMethod $search } catch { $webException = $_.Exception }
    }

    # if we found the card, output it based on the output parameter
    if ($card -ne $null)
    {
        if ($Output -eq "Image")
        {
            $tempFile = New-TemporaryFile
            $imagePath = ([IO.Path]::ChangeExtension($tempFile.FullName, "jpg"))
            Rename-Item -Path $tempFile.FullName -NewName $imagePath
            Invoke-WebRequest $card.image_uri -OutFile $imagePath
            Show-Image $imagePath
        }
        elseif ($Output -eq "Web")
        {
            Start-Process $card.scryfall_uri
        }
        elseif ($Output -eq "Text")
        {
            $textUri = "${api}/named?exact=${name}&format=text"
            $text = $null;
            try { $text = Invoke-RestMethod $textUri } catch { $webException = $_.Exception }

            if ($text -ne $null)
            {
                $text
            }
        }
        elseif ($Output -eq "Json")
        {
            $card
        }
    }
    # If we found multiple cards, we print the names and save the numbers in a global
    # array for quick access by number
    elseif ($cardList.data.Length -gt 0) 
    {
        $num = 0
        $Global:lastCards=@{}
        foreach ($item in $cardList.data)
        {
            $itemName = $item.name

            $Global:lastCards.Add($num++, $itemName)
            $cardString = Convert-MtgCardToString $item

            "{0,2}. {1}" -f ${num}, $cardString
        }
    }
    # Otherwise we didn't find anything
    else 
    {
        Write-Host "No cards found"    
    }
}

function Convert-MtgCardToString
{
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
            [Object]$card
    )

    $set = $card.set.ToUpper()

    return "$($card.name) [$set]"
}

function Show-Image
{
    Param([Parameter(Mandatory=$true, Position=0)][string]$image)
    
    [void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

    $img = [System.Drawing.Image]::FromFile($image)

    $form = new-object Windows.Forms.Form
    $form.Text = $image
    $form.Width = $img.Size.Width;
    $form.Height =  $img.Size.Height;

    $pictureBox = new-object Windows.Forms.PictureBox
    $pictureBox.Dock = "fill"
    $pictureBox.SizeMode = 4
    $pictureBox.Image = $img;
    $form.controls.add($pictureBox)
    $form.Add_Shown( { $form.Activate() } )
    $form.ShowDialog() | Out-Null
}
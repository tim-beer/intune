$archive = 'C:\Windows\Temp\AdobeReader2017.zip'
$Install = 'C:\Windows\Temp\AdobeReader'
$url = 'insert your url including the ?SV part'
Invoke-WebRequest $url -OutFile $archive -UseBasicParsing
Expand-Archive -Path $archive -DestinationPath $Install
$Install = 'C:\Windows\Temp\AdobeReader'
$args = @(
"/I" 
"$Install\AcroRead.msi"
"TRANSFORMS=$Install\AcroRead.mst"
"/Q"
)
Start-Process msiexec.exe -Wait -ArgumentList $args
Remove-Item -path $archive -Recurse

Remove-Item -path $Install -Recurse
# EncryptPassword.ps1
# Helper script to encrypt a password for use in RDP files
# Run this on a Windows machine to generate the encrypted password hex string

Write-Host ""
Write-Host "=========================================="
Write-Host "RDP Password Encryption Helper"
Write-Host "=========================================="
Write-Host ""
Write-Host "This script encrypts a password using Windows DPAPI for use in RDP files."
Write-Host ""

# Prompt for password
$password = Read-Host -Prompt "Enter the password to encrypt" -AsSecureString

# Convert SecureString to plain text for encryption
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
$plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

if ([string]::IsNullOrWhiteSpace($plainPassword)) {
    Write-Error "Password cannot be empty"
    exit 1
}

try {
    # Encrypt using DPAPI
    $passwordBytes = [System.Text.Encoding]::Unicode.GetBytes($plainPassword)
    $encryptedBytes = [System.Security.Cryptography.ProtectedData]::Protect(
        $passwordBytes,
        $null,
        [System.Security.Cryptography.DataProtectionScope]::CurrentUser
    )
    $hexPassword = [System.BitConverter]::ToString($encryptedBytes) -replace '-', ''

    Write-Host ""
    Write-Host "✓ Password encrypted successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Copy the following line to your config.ps1 file:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "`$encryptedPassword = `"$hexPassword`"" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Note: This encrypted password will only work for YOUR Windows user account." -ForegroundColor Yellow
    Write-Host "      If training participants use different Windows accounts, they may still" -ForegroundColor Yellow
    Write-Host "      need to enter the password on first connection." -ForegroundColor Yellow
    Write-Host ""
}
catch {
    Write-Error "Failed to encrypt password: $_"
    exit 1
}
finally {
    # Clear the plain password from memory
    $plainPassword = $null
}

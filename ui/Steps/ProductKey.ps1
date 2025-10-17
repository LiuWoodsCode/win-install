function Get-Step-ProductKey {
    return @{
        Name = 'ProductKey'
        Render = {
            param($panel, $fonts)

            $title = New-Object System.Windows.Forms.Label
            $title.Text = 'Let''s enter your product key'
            $title.Font = $fonts.Header
            $title.AutoSize = $true
            $panel.Controls.Add($title)

            $desc = New-Object System.Windows.Forms.Label
            $desc.Text = 'Enter your product key to activate Windows. It should match the edition you selected.'
            $desc.Font = $fonts.Body
            $desc.Size = New-Object System.Drawing.Size(520, 48)
            $desc.Location = New-Object System.Drawing.Point(0, 48)
            $panel.Controls.Add($desc)

            $keyInput = New-Object System.Windows.Forms.TextBox
            $keyInput.Font = New-Object System.Drawing.Font('Consolas', 14)
            $keyInput.Size = New-Object System.Drawing.Size(420, 32)
            $keyInput.Location = New-Object System.Drawing.Point(0, 112)
            $keyInput.MaxLength = 29
            $keyInput.Text = 'XXXXX-XXXXX-XXXXX-XXXXX-XXXXX'
            $panel.Controls.Add($keyInput)

            return @{
                Secondary = @{
                    Text = 'Skip for now'
                    Action = {
                        $answer = [System.Windows.Forms.MessageBox]::Show('Are you sure you want to skip entering the product key? You can continue without it, but you might not be able to activate Windows later.', 'PixelSetup', [System.Windows.Forms.MessageBoxButtons]::OKCancel, [System.Windows.Forms.MessageBoxIcon]::Warning)
                        if ($answer -eq [System.Windows.Forms.DialogResult]::OK) { Move-Next }
                    }
                }
            }
        }
    }
}

function Get-Step-Complete {
    return @{
        Name = 'Complete'
        Render = {
            param($panel, $fonts)

            $title = New-Object System.Windows.Forms.Label
            $title.Text = 'All done!'
            $title.Font = $fonts.Header
            $title.AutoSize = $true
            $panel.Controls.Add($title)

            $desc = New-Object System.Windows.Forms.Label
            $desc.Text = 'Windows has finished installing. Your PC will restart automatically in 15 seconds if you don''t do anything.'
            $desc.Font = $fonts.Body
            $desc.Size = New-Object System.Drawing.Size(520, 60)
            $desc.Location = New-Object System.Drawing.Point(0, 48)
            $panel.Controls.Add($desc)

            $countdownLabel = New-Object System.Windows.Forms.Label
            $countdownLabel.Text = 'Restarting in 15 seconds...'
            $countdownLabel.Font = $fonts.Body
            $countdownLabel.AutoSize = $true
            $countdownLabel.Location = New-Object System.Drawing.Point(0, 120)
            $panel.Controls.Add($countdownLabel)

            $seconds = 15
            $timer = New-Object System.Windows.Forms.Timer
            $timer.Interval = 1000
            $timer.Add_Tick({
                $seconds--
                if ($seconds -le 0) {
                    $timer.Stop()
                    $form.Close()
                }
                else {
                    $countdownLabel.Text = "Restarting in $seconds seconds..."
                }
            })
            $timer.Start()

            return @{
                NextText = 'Restart now'
                Secondary = @{
                    Text = 'Continue in PE'
                    Action = {
                        [System.Windows.Forms.MessageBox]::Show('Continuing in PE (mock).', 'PixelSetup') | Out-Null
                    }
                }
                Timer = $timer
            }
        }
    }
}

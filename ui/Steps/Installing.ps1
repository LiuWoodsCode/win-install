function Get-Step-Installing {
    return @{
        Name = 'Installing'
        Render = {
            param($panel, $fonts)

            $title = New-Object System.Windows.Forms.Label
            $title.Text = 'Installing Windows...'
            $title.Font = $fonts.Header
            $title.AutoSize = $true
            $panel.Controls.Add($title)

            $desc = New-Object System.Windows.Forms.Label
            $desc.Text = 'Please keep your PC on and connected to power. This might take a while.'
            $desc.Font = $fonts.Body
            $desc.AutoSize = $true
            $desc.Location = New-Object System.Drawing.Point(0, 48)
            $panel.Controls.Add($desc)

            # Replaced Details view + Status column with icon-based "List" view (matches mockup)
            $listView = New-Object System.Windows.Forms.ListView
            $listView.View = 'List'
            $listView.FullRowSelect = $false
            $listView.BorderStyle = 'None'
            $listView.HideSelection = $true
            $listView.Size = New-Object System.Drawing.Size(360, 200)
            $listView.Location = New-Object System.Drawing.Point(0, 96)

            # Create colored circle icons for states
            $imageList = New-Object System.Windows.Forms.ImageList
            $imageList.ImageSize = New-Object System.Drawing.Size(16,16)

            $createCircle = {
                param([System.Drawing.Color]$color)
                $bmp = New-Object System.Drawing.Bitmap 16,16
                $g = [System.Drawing.Graphics]::FromImage($bmp)
                $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
                $g.Clear([System.Drawing.Color]::Transparent)
                $brush = New-Object System.Drawing.SolidBrush($color)
                $g.FillEllipse($brush, 0, 0, 15, 15)
                $brush.Dispose(); $g.Dispose()
                $bmp
            }

            $colorDone    = [System.Drawing.Color]::FromArgb(0, 200, 80)   # green
            $colorActive  = [System.Drawing.Color]::FromArgb(0, 120, 255)  # blue
            $colorPending = [System.Drawing.Color]::FromArgb(150,150,150)  # gray

            $null = $imageList.Images.Add('done',    (& $createCircle $colorDone))
            $null = $imageList.Images.Add('active',  (& $createCircle $colorActive))
            $null = $imageList.Images.Add('pending', (& $createCircle $colorPending))

            $listView.SmallImageList = $imageList

            # Items shown like the mockup
            $steps = @('Item A','Item B','Item C','Item D','Item E','Item F')

            foreach ($step in $steps) {
                $li = New-Object System.Windows.Forms.ListViewItem($step)
                $li.ImageKey = 'pending'
                $null = $listView.Items.Add($li)
            }

            $panel.Controls.Add($listView)

            # Store state on the ListView to ensure scope-safe access in the timer
            $ctx = [pscustomobject]@{
                Steps       = $steps
                ActiveIndex = 0
                Percent     = 0
            }
            $listView.Tag = $ctx

            # Initialize first active item using stored context
            $listView.Items[$ctx.ActiveIndex].ImageKey = 'active'
            $listView.Items[$ctx.ActiveIndex].Text = "$($ctx.Steps[$ctx.ActiveIndex]) (0%)"

            $timer = New-Object System.Windows.Forms.Timer
            $timer.Interval = 200  # smooth animation

            $timer.Add_Tick({
                param($sender, $e)

                $ctx = $listView.Tag
                if ($null -eq $ctx -or $null -eq $ctx.Steps) { $sender.Stop(); return }

                if ($ctx.ActiveIndex -ge $listView.Items.Count) {
                    $sender.Stop()
                    return
                }

                $ctx.Percent += 5

                if ($ctx.Percent -ge 100) {
                    # complete current
                    $listView.Items[$ctx.ActiveIndex].ImageKey = 'done'
                    $listView.Items[$ctx.ActiveIndex].Text = $ctx.Steps[$ctx.ActiveIndex]

                    $ctx.ActiveIndex++
                    $ctx.Percent = 0

                    if ($ctx.ActiveIndex -lt $listView.Items.Count) {
                        $listView.Items[$ctx.ActiveIndex].ImageKey = 'active'
                        $listView.Items[$ctx.ActiveIndex].Text = "$($ctx.Steps[$ctx.ActiveIndex]) (0%)"
                    }
                    else {
                        $sender.Stop()
                    }
                }
                else {
                    # update active item percent text
                    if ($ctx.ActiveIndex -lt $listView.Items.Count) {
                        $listView.Items[$ctx.ActiveIndex].Text = "$($ctx.Steps[$ctx.ActiveIndex]) ($($ctx.Percent)%)"
                    }
                }
            })
            $timer.Start()

            return @{
                NextText = 'Next'
                Timer   = $timer
            }
        }
    }
}

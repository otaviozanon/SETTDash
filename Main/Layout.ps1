#region XAML DASHBOARD LAYOUT
[xml]$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Width="1200" Height="740"
    WindowStyle="None"
    AllowsTransparency="True"
    Background="{DynamicResource Brush_WindowBg}"
    BorderBrush="{DynamicResource Brush_Border}"
    FontFamily="{DynamicResource Theme_FontFamily}"
    BorderThickness="1"
    ResizeMode="CanResizeWithGrip"
    TextOptions.TextFormattingMode="Display"
    TextOptions.TextRenderingMode="Grayscale"
    UseLayoutRounding="True"
    RenderOptions.ClearTypeHint="Enabled">

    <Window.Resources>
        <!-- ==================== THEME RESOURCE DEFAULTS ====================
             These MUST exist at initial XAML parse time so every {DynamicResource}
             binding resolves to a real Brush/value immediately. Set-GuiTheme later
             overwrites these same keys at runtime to switch themes; WPF only
             crashes on DynamicResource keys that are missing at parse time and
             added afterward, not on keys that already exist and get replaced. -->
        <SolidColorBrush x:Key="Brush_WindowBg" Color="#0D1117"/>
        <SolidColorBrush x:Key="Brush_Border" Color="#30363D"/>
        <SolidColorBrush x:Key="Brush_SidebarBg" Color="#0D1117"/>
        <SolidColorBrush x:Key="Brush_CardBg" Color="#11151B"/>
        <SolidColorBrush x:Key="Brush_CardBorder" Color="#21262D"/>
        <SolidColorBrush x:Key="Brush_TextPrimary" Color="#E6EDF3"/>
        <SolidColorBrush x:Key="Brush_TextSecondary" Color="#8B949E"/>
        <SolidColorBrush x:Key="Brush_TextMuted" Color="#6E7681"/>
        <SolidColorBrush x:Key="Brush_Accent" Color="#1F6FEB"/>
        <SolidColorBrush x:Key="Brush_NavActiveBg" Color="#14181F"/>
        <SolidColorBrush x:Key="Brush_TitleBarBg" Color="#161B22"/>
        <SolidColorBrush x:Key="Brush_LogBg" Color="#0D1117"/>
        <SolidColorBrush x:Key="Brush_LogBorder" Color="#30363D"/>
        <SolidColorBrush x:Key="Brush_LogText" Color="#8B949E"/>
        <SolidColorBrush x:Key="Brush_HoverBg" Color="#161B22"/>
        <SolidColorBrush x:Key="Brush_PressedBg" Color="#1C2128"/>
        <SolidColorBrush x:Key="Brush_Disabled" Color="#484F58"/>
        <SolidColorBrush x:Key="Brush_GaugeTrack" Color="#242A32"/>
        <SolidColorBrush x:Key="Brush_GaugeDot" Color="#1F6FEB"/>
        <SolidColorBrush x:Key="Brush_ProgressTrack" Color="#21262D"/>
        <SolidColorBrush x:Key="Brush_Divider" Color="#282E36"/>
        <SolidColorBrush x:Key="Brush_ScrollThumb" Color="#30363D"/>
        <SolidColorBrush x:Key="Brush_Danger" Color="#6E2C2C"/>
        <SolidColorBrush x:Key="Brush_DangerHover" Color="#F85149"/>
        <SolidColorBrush x:Key="Brush_DangerPressed" Color="#A32D2A"/>
        <SolidColorBrush x:Key="Brush_ProgressOverlay" Color="Transparent"/>
        <CornerRadius x:Key="Theme_CornerRadius">6</CornerRadius>
        <FontFamily x:Key="Theme_FontFamily">Segoe UI</FontFamily>

        <!-- ==================== NAV BUTTON STYLE ==================== -->
        <Style x:Key="NavButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="{DynamicResource Brush_TextSecondary}"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Height" Value="34"/>
            <Setter Property="Margin" Value="10,0,10,0"/>
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="Padding" Value="12,0,0,0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}"
                                Padding="{TemplateBinding Padding}"
                                CornerRadius="{DynamicResource Theme_CornerRadius}">
                            <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
                                              VerticalAlignment="Center"
                                              TextBlock.Foreground="{TemplateBinding Foreground}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="{DynamicResource Brush_HoverBg}"/>
                                <Setter Property="Foreground" Value="{DynamicResource Brush_TextPrimary}"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="{DynamicResource Brush_PressedBg}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ==================== NAV BUTTON ACTIVE STYLE ==================== -->
        <Style x:Key="NavButtonActiveStyle" TargetType="Button">
            <Setter Property="Background" Value="{DynamicResource Brush_NavActiveBg}"/>
            <Setter Property="Foreground" Value="{DynamicResource Brush_TextPrimary}"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Height" Value="34"/>
            <Setter Property="Margin" Value="10,0,10,0"/>
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="Padding" Value="12,0,0,0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Grid>
                            <Border x:Name="border" Background="{TemplateBinding Background}"
                                    Padding="{TemplateBinding Padding}"
                                    CornerRadius="{DynamicResource Theme_CornerRadius}">
                                <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
                                                  VerticalAlignment="Center"
                                                  TextBlock.Foreground="{TemplateBinding Foreground}"/>
                            </Border>
                            <Border Width="3" HorizontalAlignment="Left" Background="{DynamicResource Brush_Accent}" CornerRadius="0,2,2,0" Margin="-10,4,0,4"/>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="{DynamicResource Brush_HoverBg}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ==================== CATEGORY PILL STYLE (used by Show-GuiCategoryDetailPage) ==================== -->
        <Style x:Key="CategoryPillStyle" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="{DynamicResource Brush_TextSecondary}"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Height" Value="28"/>
            <Setter Property="Margin" Value="0,2,6,2"/>
            <Setter Property="HorizontalContentAlignment" Value="Center"/>
            <Setter Property="Padding" Value="14,0,14,0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="{DynamicResource Brush_CardBorder}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                Padding="{TemplateBinding Padding}"
                                CornerRadius="14">
                            <ContentPresenter HorizontalAlignment="Center"
                                              VerticalAlignment="Center"
                                              TextBlock.Foreground="{TemplateBinding Foreground}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="{DynamicResource Brush_HoverBg}"/>
                                <Setter Property="Foreground" Value="{DynamicResource Brush_TextPrimary}"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="{DynamicResource Brush_PressedBg}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ==================== CATEGORY PILL ACTIVE STYLE ==================== -->
        <Style x:Key="CategoryPillActiveStyle" TargetType="Button" BasedOn="{StaticResource CategoryPillStyle}">
            <Setter Property="Background" Value="{DynamicResource Brush_Accent}"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="BorderBrush" Value="{DynamicResource Brush_Accent}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                Padding="{TemplateBinding Padding}"
                                CornerRadius="14">
                            <ContentPresenter HorizontalAlignment="Center"
                                              VerticalAlignment="Center"
                                              TextBlock.Foreground="{TemplateBinding Foreground}"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ==================== NAV HEADER STYLE ==================== -->
        <Style x:Key="NavHeaderStyle" TargetType="Button">
            <Setter Property="Foreground" Value="{DynamicResource Brush_TextMuted}"/>
            <Setter Property="FontSize" Value="11"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Height" Value="28"/>
            <Setter Property="Margin" Value="20,16,10,6"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" Padding="0,0,0,0">
                            <ContentPresenter HorizontalAlignment="Left" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Foreground" Value="{DynamicResource Brush_TextSecondary}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ==================== ACTION BUTTON STYLE ==================== -->
        <Style x:Key="ActionButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <!-- Brighter/primary text: positive action is meant to draw more attention than Revert. -->
            <Setter Property="Foreground" Value="{DynamicResource Brush_TextPrimary}"/>
            <Setter Property="FontSize" Value="11"/>
            <!-- Positive/optimization action (Apply, Run, Optimize, Scan, Clean, Install, etc.) -> bold,
                 so it visually reads as the "do something good" action versus RevertButtonStyle below. -->
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="MinHeight" Value="28"/>
            <Setter Property="MinWidth" Value="0"/>
            <Setter Property="Width" Value="Auto"/>
            <Setter Property="Padding" Value="10,0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="{DynamicResource Brush_Border}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                Padding="{TemplateBinding Padding}"
                                CornerRadius="{DynamicResource Theme_CornerRadius}"
                                MinHeight="{TemplateBinding MinHeight}"
                                MinWidth="{TemplateBinding MinWidth}">
                         <TextBlock Text="{TemplateBinding Content}"
                                       TextWrapping="Wrap"
                                       HorizontalAlignment="Center"
                                       VerticalAlignment="Center"
                                       FontWeight="{TemplateBinding FontWeight}"
                                       Foreground="{TemplateBinding Foreground}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="BorderBrush" Value="{DynamicResource Brush_Accent}"/>
                                <Setter Property="Foreground" Value="{DynamicResource Brush_Accent}"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="{DynamicResource Brush_HoverBg}"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="BorderBrush" Value="{DynamicResource Brush_CardBorder}"/>
                                <Setter Property="Foreground" Value="{DynamicResource Brush_Disabled}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ==================== TOGGLE SWITCH STYLE ====================
             Pill-shaped on/off switch (ToggleButton): track changes color (gray/accent) and the
             thumb slides left/right based on IsChecked. Used by Add-GuiToggleCard (Settings). -->
        <Style x:Key="ToggleSwitchStyle" TargetType="ToggleButton">
            <Setter Property="Width" Value="42"/>
            <Setter Property="Height" Value="22"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ToggleButton">
                        <Border x:Name="track" CornerRadius="11" Background="{DynamicResource Brush_Disabled}">
                            <Grid>
                                <Ellipse x:Name="thumb" Width="16" Height="16" Fill="White"
                                         HorizontalAlignment="Left" Margin="3,0,0,0"/>
                            </Grid>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="track" Property="Background" Value="{DynamicResource Brush_Accent}"/>
                                <Setter TargetName="thumb" Property="HorizontalAlignment" Value="Right"/>
                                <Setter TargetName="thumb" Property="Margin" Value="0,0,3,0"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ==================== INSTALL BUTTON STYLE ==================== -->
        <!-- Same look as ActionButtonStyle (primary text color) but Normal weight: used for
             neutral "program" actions (install/launch/download/open) that are not an
             optimize/fix/apply action, so bold stays reserved for those. -->
        <Style x:Key="InstallButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="{DynamicResource Brush_TextPrimary}"/>
            <Setter Property="FontSize" Value="11"/>
            <Setter Property="FontWeight" Value="Normal"/>
            <Setter Property="MinHeight" Value="28"/>
            <Setter Property="MinWidth" Value="0"/>
            <Setter Property="Width" Value="Auto"/>
            <Setter Property="Padding" Value="10,0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="{DynamicResource Brush_Border}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                Padding="{TemplateBinding Padding}"
                                CornerRadius="{DynamicResource Theme_CornerRadius}"
                                MinHeight="{TemplateBinding MinHeight}"
                                MinWidth="{TemplateBinding MinWidth}">
                         <TextBlock Text="{TemplateBinding Content}"
                                       TextWrapping="Wrap"
                                       HorizontalAlignment="Center"
                                       VerticalAlignment="Center"
                                       FontWeight="{TemplateBinding FontWeight}"
                                       Foreground="{TemplateBinding Foreground}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="BorderBrush" Value="{DynamicResource Brush_Accent}"/>
                                <Setter Property="Foreground" Value="{DynamicResource Brush_Accent}"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="{DynamicResource Brush_HoverBg}"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="BorderBrush" Value="{DynamicResource Brush_CardBorder}"/>
                                <Setter Property="Foreground" Value="{DynamicResource Brush_Disabled}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ==================== REVERT BUTTON STYLE ==================== -->
        <Style x:Key="RevertButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <!-- Muted/secondary text: negative action should read as less prominent than ActionButtonStyle. -->
            <Setter Property="Foreground" Value="{DynamicResource Brush_TextSecondary}"/>
            <Setter Property="FontSize" Value="11"/>
            <Setter Property="FontWeight" Value="Normal"/>
            <Setter Property="MinHeight" Value="28"/>
            <Setter Property="MinWidth" Value="0"/>
            <Setter Property="Width" Value="Auto"/>
            <Setter Property="Padding" Value="10,0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="{DynamicResource Brush_Border}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                Padding="{TemplateBinding Padding}"
                                CornerRadius="{DynamicResource Theme_CornerRadius}"
                                MinHeight="{TemplateBinding MinHeight}"
                                MinWidth="{TemplateBinding MinWidth}">
                         <TextBlock Text="{TemplateBinding Content}"
                                       TextWrapping="Wrap"
                                       HorizontalAlignment="Center"
                                       VerticalAlignment="Center"
                                       FontWeight="{TemplateBinding FontWeight}"
                                       Foreground="{TemplateBinding Foreground}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="BorderBrush" Value="{DynamicResource Brush_Accent}"/>
                                <Setter Property="Foreground" Value="{DynamicResource Brush_Accent}"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="{DynamicResource Brush_HoverBg}"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="BorderBrush" Value="{DynamicResource Brush_CardBorder}"/>
                                <Setter Property="Foreground" Value="{DynamicResource Brush_Disabled}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ==================== DANGER BUTTON STYLE ==================== -->
        <Style x:Key="DangerButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="{DynamicResource Brush_Danger}"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontSize" Value="11"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="MinHeight" Value="28"/>
            <Setter Property="MinWidth" Value="0"/>
            <Setter Property="Width" Value="Auto"/>
            <Setter Property="Padding" Value="10,0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="{DynamicResource Brush_Danger}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                Padding="{TemplateBinding Padding}"
                                CornerRadius="{DynamicResource Theme_CornerRadius}"
                                MinHeight="{TemplateBinding MinHeight}"
                                MinWidth="{TemplateBinding MinWidth}">
                         <TextBlock Text="{TemplateBinding Content}"
                                       TextWrapping="Wrap"
                                       HorizontalAlignment="Center"
                                       VerticalAlignment="Center"
                                       Foreground="{TemplateBinding Foreground}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="{DynamicResource Brush_DangerHover}"/>
                                <Setter TargetName="border" Property="BorderBrush" Value="{DynamicResource Brush_DangerHover}"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="{DynamicResource Brush_DangerPressed}"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="Background" Value="{DynamicResource Brush_CardBorder}"/>
                                <Setter Property="Foreground" Value="{DynamicResource Brush_Disabled}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ==================== TOOL BUTTON STYLE ==================== -->
        <Style x:Key="ToolButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="{DynamicResource Brush_TextSecondary}"/>
            <Setter Property="FontSize" Value="11"/>
            <Setter Property="MinHeight" Value="26"/>
            <Setter Property="MinWidth" Value="0"/>
            <Setter Property="Padding" Value="10,0"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="{DynamicResource Brush_Border}"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="{DynamicResource Theme_CornerRadius}" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="BorderBrush" Value="{DynamicResource Brush_Accent}"/>
                                <Setter Property="Foreground" Value="{DynamicResource Brush_Accent}"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="{DynamicResource Brush_HoverBg}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ==================== CARD STYLE ==================== -->
        <Style x:Key="CardStyle" TargetType="Border">
            <Setter Property="Background" Value="{DynamicResource Brush_CardBg}"/>
            <Setter Property="BorderBrush" Value="{DynamicResource Brush_CardBorder}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CornerRadius" Value="{DynamicResource Theme_CornerRadius}"/>
            <Setter Property="Padding" Value="14"/>
            <Setter Property="Margin" Value="0,0,0,10"/>
            <Setter Property="Effect">
                <Setter.Value>
                    <DropShadowEffect Color="#000000" BlurRadius="10" ShadowDepth="2" Opacity="0.25"/>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <!-- Growth is done via Margin (not ScaleTransform) so child TextBlocks never get
                         rasterized at a fractional scale - a ScaleTransform here blurs the text during
                         the hover animation since WPF has to resample glyphs off-pixel-grid. -->
                    <Trigger.EnterActions>
                        <BeginStoryboard>
                            <Storyboard>
                                <DoubleAnimation Storyboard.TargetProperty="(Border.Effect).(DropShadowEffect.BlurRadius)" To="18" Duration="0:0:0.15"/>
                                <DoubleAnimation Storyboard.TargetProperty="(Border.Effect).(DropShadowEffect.Opacity)" To="0.45" Duration="0:0:0.15"/>
                                <ThicknessAnimation Storyboard.TargetProperty="Margin" To="-3,-3,-3,7" Duration="0:0:0.15"/>
                            </Storyboard>
                        </BeginStoryboard>
                    </Trigger.EnterActions>
                    <Trigger.ExitActions>
                        <BeginStoryboard>
                            <Storyboard>
                                <DoubleAnimation Storyboard.TargetProperty="(Border.Effect).(DropShadowEffect.BlurRadius)" To="10" Duration="0:0:0.15"/>
                                <DoubleAnimation Storyboard.TargetProperty="(Border.Effect).(DropShadowEffect.Opacity)" To="0.25" Duration="0:0:0.15"/>
                                <ThicknessAnimation Storyboard.TargetProperty="Margin" To="0,0,0,10" Duration="0:0:0.15"/>
                            </Storyboard>
                        </BeginStoryboard>
                    </Trigger.ExitActions>
                    <Setter Property="BorderBrush" Value="{DynamicResource Brush_Accent}"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <!-- ==================== INFO CARD STYLE ====================
             Same look as CardStyle but WITHOUT the hover-grow animation. Used by read-only
             hardware info cards (Add-GuiInfoCard: Sensors/GPU/CPU/Disks/Energy pages) which
             aren't clickable - the hover grow effect served no purpose there and, worse, the
             few pixels of extra width during the Margin animation could shift where long text
             (e.g. the battery "Notes" row) wraps, making line breaks appear/disappear on hover. -->
        <Style x:Key="InfoCardStyle" TargetType="Border">
            <Setter Property="Background" Value="{DynamicResource Brush_CardBg}"/>
            <Setter Property="BorderBrush" Value="{DynamicResource Brush_CardBorder}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CornerRadius" Value="{DynamicResource Theme_CornerRadius}"/>
            <Setter Property="Padding" Value="14"/>
            <Setter Property="Margin" Value="0,0,0,10"/>
            <Setter Property="Effect">
                <Setter.Value>
                    <DropShadowEffect Color="#000000" BlurRadius="10" ShadowDepth="2" Opacity="0.25"/>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ==================== CARD TITLE STYLE ==================== -->
        <Style x:Key="CardTitleStyle" TargetType="TextBlock">
            <Setter Property="Foreground" Value="{DynamicResource Brush_TextPrimary}"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Margin" Value="0,0,0,4"/>
        </Style>

        <!-- ==================== CARD DESCRIPTION STYLE ==================== -->
        <Style x:Key="CardDescStyle" TargetType="TextBlock">
            <Setter Property="Foreground" Value="{DynamicResource Brush_TextSecondary}"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="LineHeight" Value="17"/>
            <Setter Property="TextWrapping" Value="Wrap"/>
            <Setter Property="Margin" Value="0,0,0,14"/>
        </Style>

        <!-- ==================== SECTION LABEL STYLE (minimal eyebrow) ==================== -->
        <Style x:Key="SectionLabelStyle" TargetType="TextBlock">
            <Setter Property="Foreground" Value="{DynamicResource Brush_TextMuted}"/>
            <Setter Property="FontSize" Value="11"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Margin" Value="0,0,0,10"/>
        </Style>

        <!-- ==================== LOG BOX STYLE ==================== -->
        <!-- RichTextBox has no border/hover setters of its own here, so without a custom template
             it falls back to the default WPF chrome, whose built-in triggers force the border to a
             hardcoded system blue on hover/focus regardless of BorderBrush. This template replaces
             that chrome: idle border is Brush_LogBorder (dark gray in both themes), and it only turns
             Brush_Accent (blue in Default, orange in Terminal Retro) while the mouse is actually over
             it - not on keyboard focus, since the log is read-only and focus alone shouldn't light it up. -->
        <Style x:Key="LogBoxStyle" TargetType="RichTextBox">
            <Setter Property="BorderBrush" Value="{DynamicResource Brush_LogBorder}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="RichTextBox">
                        <Border x:Name="border" Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}">
                            <ScrollViewer x:Name="PART_ContentHost"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="BorderBrush" Value="{DynamicResource Brush_Accent}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ==================== THEMED COMBOBOX STYLE ====================
             Used by New-GuiThemedComboBox (Core/Helpers/Cards.ps1) as a dropdown alternative to the
             pill-button pickers (e.g. BenchGpu.ps1's test type/length selectors). Replaces the default
             WPF ComboBox chrome (which ignores Background/Foreground/BorderBrush on its toggle button
             and popup) with a template that actually follows the active theme via DynamicResource,
             same approach as NavButtonStyle/CategoryPillStyle above. -->
        <Style x:Key="ThemedComboBoxItemStyle" TargetType="ComboBoxItem">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="{DynamicResource Brush_TextPrimary}"/>
            <Setter Property="Padding" Value="8,5"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBoxItem">
                        <Border x:Name="itemBorder" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}">
                            <ContentPresenter/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsHighlighted" Value="True">
                                <Setter TargetName="itemBorder" Property="Background" Value="{DynamicResource Brush_HoverBg}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="ThemedComboBoxStyle" TargetType="ComboBox">
            <Setter Property="Background" Value="{DynamicResource Brush_CardBg}"/>
            <Setter Property="Foreground" Value="{DynamicResource Brush_TextPrimary}"/>
            <Setter Property="BorderBrush" Value="{DynamicResource Brush_CardBorder}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="8,4"/>
            <Setter Property="FontFamily" Value="{DynamicResource Theme_FontFamily}"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="ItemContainerStyle" Value="{StaticResource ThemedComboBoxItemStyle}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBox">
                        <Grid>
                            <ToggleButton x:Name="toggle"
                                          Background="{TemplateBinding Background}"
                                          BorderBrush="{TemplateBinding BorderBrush}"
                                          BorderThickness="{TemplateBinding BorderThickness}"
                                          IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}"
                                          Focusable="False" ClickMode="Press">
                                <ToggleButton.Template>
                                    <ControlTemplate TargetType="ToggleButton">
                                        <Border x:Name="toggleBorder" Background="{TemplateBinding Background}"
                                                BorderBrush="{TemplateBinding BorderBrush}"
                                                BorderThickness="{TemplateBinding BorderThickness}"
                                                CornerRadius="{DynamicResource Theme_CornerRadius}">
                                            <Grid>
                                                <Grid.ColumnDefinitions>
                                                    <ColumnDefinition Width="*"/>
                                                    <ColumnDefinition Width="20"/>
                                                </Grid.ColumnDefinitions>
                                                <Path Grid.Column="1" Data="M0,0 L4,4 L8,0 Z" Fill="{DynamicResource Brush_TextSecondary}"
                                                      HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                            </Grid>
                                        </Border>
                                        <ControlTemplate.Triggers>
                                            <Trigger Property="IsMouseOver" Value="True">
                                                <Setter TargetName="toggleBorder" Property="Background" Value="{DynamicResource Brush_HoverBg}"/>
                                            </Trigger>
                                        </ControlTemplate.Triggers>
                                    </ControlTemplate>
                                </ToggleButton.Template>
                            </ToggleButton>
                            <ContentPresenter x:Name="contentPresenter" IsHitTestVisible="False"
                                              Content="{TemplateBinding SelectionBoxItem}"
                                              ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                              Margin="{TemplateBinding Padding}"
                                              HorizontalAlignment="Left" VerticalAlignment="Center"
                                              TextBlock.Foreground="{TemplateBinding Foreground}"/>
                            <Popup x:Name="PART_Popup" IsOpen="{TemplateBinding IsDropDownOpen}"
                                   Placement="Bottom" AllowsTransparency="True" Focusable="False" PopupAnimation="None">
                                <Border Background="{DynamicResource Brush_CardBg}" BorderBrush="{DynamicResource Brush_CardBorder}"
                                        BorderThickness="1" CornerRadius="{DynamicResource Theme_CornerRadius}"
                                        MinWidth="{TemplateBinding ActualWidth}" MaxHeight="200">
                                    <ScrollViewer>
                                        <ItemsPresenter/>
                                    </ScrollViewer>
                                </Border>
                            </Popup>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ==================== PAGE TITLE STYLE ==================== -->
        <Style x:Key="PageTitleStyle" TargetType="TextBlock">
            <Setter Property="Foreground" Value="{DynamicResource Brush_TextPrimary}"/>
            <Setter Property="FontSize" Value="20"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Margin" Value="0,0,0,12"/>
        </Style>

        <!-- ==================== PROGRESS BAR STYLE ==================== -->
        <Style x:Key="ProgressBarStyle" TargetType="ProgressBar">
            <Setter Property="Height" Value="10"/>
            <Setter Property="Background" Value="{DynamicResource Brush_ProgressTrack}"/>
            <Setter Property="Foreground" Value="{DynamicResource Brush_Accent}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="{DynamicResource Brush_Border}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ProgressBar">
                        <Grid>
                            <Border Background="{TemplateBinding Background}"
                                    BorderBrush="{TemplateBinding BorderBrush}"
                                    BorderThickness="{TemplateBinding BorderThickness}"
                                    CornerRadius="{DynamicResource Theme_CornerRadius}"/>
                            <Border x:Name="PART_Track" Background="Transparent" Margin="1"
                                    CornerRadius="{DynamicResource Theme_CornerRadius}" BorderThickness="0">
                                <Border x:Name="PART_Indicator" Background="{TemplateBinding Foreground}"
                                        CornerRadius="{DynamicResource Theme_CornerRadius}" BorderThickness="0"
                                        HorizontalAlignment="Left">
                                    <Border Background="{DynamicResource Brush_ProgressOverlay}"/>
                                </Border>
                            </Border>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ==================== CLOSE BUTTON STYLE ==================== -->
        <Style x:Key="CloseButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="{DynamicResource Brush_TextSecondary}"/>
            <Setter Property="FontFamily" Value="Segoe MDL2 Assets"/>
            <Setter Property="FontSize" Value="10"/>
            <Setter Property="Width" Value="46"/>
            <Setter Property="Height" Value="32"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}"
                                Width="{TemplateBinding Width}"
                                Height="{TemplateBinding Height}">
                         <TextBlock Text="{TemplateBinding Content}"
                                       TextWrapping="Wrap"
                                       HorizontalAlignment="Center"
                                       VerticalAlignment="Center"
                                       Foreground="{TemplateBinding Foreground}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="{DynamicResource Brush_DangerHover}"/>
                                <Setter Property="Foreground" Value="White"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ==================== MINIMIZE BUTTON STYLE ==================== -->
        <Style x:Key="MinButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="{DynamicResource Brush_TextSecondary}"/>
            <Setter Property="FontFamily" Value="Segoe MDL2 Assets"/>
            <Setter Property="FontSize" Value="10"/>
            <Setter Property="Width" Value="46"/>
            <Setter Property="Height" Value="32"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}"
                                Width="{TemplateBinding Width}"
                                Height="{TemplateBinding Height}">
                         <TextBlock Text="{TemplateBinding Content}"
                                       TextWrapping="Wrap"
                                       HorizontalAlignment="Center"
                                       VerticalAlignment="Center"
                                       Foreground="{TemplateBinding Foreground}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="{DynamicResource Brush_HoverBg}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ==================== LOG ICON BUTTON STYLE ==================== -->
        <Style x:Key="LogIconButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="{DynamicResource Brush_TextMuted}"/>
            <Setter Property="FontFamily" Value="Segoe MDL2 Assets"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Width" Value="24"/>
            <Setter Property="Height" Value="20"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}"
                                CornerRadius="3"
                                Width="{TemplateBinding Width}"
                                Height="{TemplateBinding Height}">
                            <TextBlock Text="{TemplateBinding Content}"
                                       HorizontalAlignment="Center"
                                       VerticalAlignment="Center"
                                       Foreground="{TemplateBinding Foreground}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="{DynamicResource Brush_HoverBg}"/>
                                <Setter Property="Foreground" Value="{DynamicResource Brush_TextPrimary}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ==================== SCROLLBAR STYLE ==================== -->
        <Style x:Key="ScrollBarStyle" TargetType="ScrollBar">
            <Setter Property="Width" Value="8"/>
            <Setter Property="Background" Value="{DynamicResource Brush_TitleBarBg}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ScrollBar">
                        <Border Background="{TemplateBinding Background}" CornerRadius="{DynamicResource Theme_CornerRadius}">
                            <Track x:Name="PART_Track" IsDirectionReversed="True">
                                <Track.Thumb>
                                    <Thumb Background="{DynamicResource Brush_ScrollThumb}" BorderThickness="0" Width="6">
                                        <Thumb.Template>
                                            <ControlTemplate TargetType="Thumb">
                                                <Border Background="{TemplateBinding Background}" CornerRadius="{DynamicResource Theme_CornerRadius}"/>
                                            </ControlTemplate>
                                        </Thumb.Template>
                                    </Thumb>
                                </Track.Thumb>
                            </Track>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ==================== MODERN SCROLLBAR STYLE ==================== -->
        <Style TargetType="ScrollBar">
            <Setter Property="Width" Value="7"/>
            <Setter Property="MinWidth" Value="7"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ScrollBar">
                        <Grid Background="{TemplateBinding Background}">
                            <Track x:Name="PART_Track" IsDirectionReversed="True" Width="7">
                                <Track.Thumb>
                                    <Thumb x:Name="ScrollThumb">
                                        <Thumb.Template>
                                            <ControlTemplate TargetType="Thumb">
                                                <Border x:Name="ThumbBorder" Background="{DynamicResource Brush_ScrollThumb}" CornerRadius="3.5" Margin="1,0" Width="5">
                                                    <Border.RenderTransform>
                                                        <ScaleTransform x:Name="ThumbScale" ScaleX="1"/>
                                                    </Border.RenderTransform>
                                                </Border>
                                                <ControlTemplate.Triggers>
                                                    <Trigger Property="IsMouseOver" Value="True">
                                                        <Setter TargetName="ThumbBorder" Property="Background" Value="{DynamicResource Brush_Accent}"/>
                                                        <Setter TargetName="ThumbBorder" Property="Width" Value="7"/>
                                                    </Trigger>
                                                    <Trigger Property="IsDragging" Value="True">
                                                        <Setter TargetName="ThumbBorder" Property="Background" Value="{DynamicResource Brush_Accent}"/>
                                                        <Setter TargetName="ThumbBorder" Property="Width" Value="7"/>
                                                    </Trigger>
                                                </ControlTemplate.Triggers>
                                            </ControlTemplate>
                                        </Thumb.Template>
                                    </Thumb>
                                </Track.Thumb>
                            </Track>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ==================== DATAGRID STYLE (used by Sensors page) ==================== -->
        <Style TargetType="DataGrid">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="{DynamicResource Brush_TextPrimary}"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="RowBackground" Value="Transparent"/>
            <Setter Property="AlternatingRowBackground" Value="Transparent"/>
            <Setter Property="HorizontalGridLinesBrush" Value="{DynamicResource Brush_Divider}"/>
            <Setter Property="VerticalGridLinesBrush" Value="{DynamicResource Brush_Divider}"/>
            <Setter Property="GridLinesVisibility" Value="Horizontal"/>
            <Setter Property="HeadersVisibility" Value="Column"/>
            <Setter Property="RowHeaderWidth" Value="0"/>
            <Setter Property="MinRowHeight" Value="32"/>
            <Setter Property="CanUserResizeRows" Value="False"/>
            <Setter Property="CanUserReorderColumns" Value="False"/>
            <Setter Property="CanUserResizeColumns" Value="False"/>
            <Setter Property="SelectionMode" Value="Single"/>
            <Setter Property="FontFamily" Value="{DynamicResource Theme_FontFamily}"/>
            <Setter Property="FontSize" Value="14.5"/>
        </Style>

        <Style TargetType="DataGridColumnHeader">
            <Setter Property="Foreground" Value="{DynamicResource Brush_TextMuted}"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="FontSize" Value="11.5"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="DataGridColumnHeader">
                        <Border Background="{TemplateBinding Background}" BorderBrush="{DynamicResource Brush_Divider}" BorderThickness="0,0,0,1" Padding="12,0,12,10">
                            <ContentPresenter VerticalAlignment="Bottom"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="DataGridRow">
            <Setter Property="Background" Value="Transparent"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="{DynamicResource Brush_HoverBg}"/>
                </Trigger>
                <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="{DynamicResource Brush_PressedBg}"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style TargetType="DataGridCell">
            <Setter Property="Foreground" Value="{DynamicResource Brush_TextPrimary}"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="DataGridCell">
                        <Border Background="Transparent" Padding="12,0">
                            <ContentPresenter VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="MutedCellStyle" TargetType="TextBlock">
            <Setter Property="Foreground" Value="{DynamicResource Brush_TextSecondary}"/>
            <Setter Property="FontSize" Value="13.5"/>
        </Style>
        <Style x:Key="MutedMonoCellStyle" TargetType="TextBlock">
            <Setter Property="Foreground" Value="{DynamicResource Brush_TextMuted}"/>
            <Setter Property="FontFamily" Value="Consolas"/>
            <Setter Property="FontSize" Value="14"/>
        </Style>
        <Style x:Key="MonoCellStyle" TargetType="TextBlock">
            <Setter Property="Foreground" Value="{DynamicResource Brush_TextPrimary}"/>
            <Setter Property="FontFamily" Value="Consolas"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
        </Style>

        <Style x:Key="SensorGroupHeaderStyle" TargetType="TextBlock">
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Foreground" Value="{DynamicResource Brush_TextPrimary}"/>
            <Setter Property="Margin" Value="12,18,0,6"/>
        </Style>

    </Window.Resources>

    <!-- ==================== ROOT GRID ==================== -->
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="32"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <!-- ==================== TITLE BAR ==================== -->
        <Border Grid.Row="0" x:Name="titleBar" Background="{DynamicResource Brush_TitleBarBg}"
                BorderBrush="{DynamicResource Brush_Border}" BorderThickness="0,0,0,1">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <Border Grid.Column="1" Background="Transparent">
                    <Button x:Name="btnMin" Content="&#xE921;" Style="{StaticResource MinButtonStyle}"/>
                </Border>

                <Border Grid.Column="2" Background="Transparent">
                    <Button x:Name="btnMax" Content="&#xE922;" Style="{StaticResource MinButtonStyle}"/>
                </Border>

                <Border Grid.Column="3" Background="Transparent">
                    <Button x:Name="btnClose" Content="&#xE8BB;" Style="{StaticResource CloseButtonStyle}"/>
                </Border>
            </Grid>
        </Border>

        <!-- ==================== MAIN CONTENT ==================== -->
        <Grid Grid.Row="1">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="220"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <!-- ==================== LEFT SIDEBAR ==================== -->
            <Border Grid.Column="0" Background="{DynamicResource Brush_SidebarBg}"
                    BorderBrush="{DynamicResource Brush_Border}" BorderThickness="0,0,1,0">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>

                    <!-- Sidebar brand header -->
                    <Border Grid.Row="0" Background="{DynamicResource Brush_SidebarBg}"
                            BorderBrush="{DynamicResource Brush_Border}" BorderThickness="0,0,0,1"
                            Padding="14,16,14,16">
                        <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                            <TextBlock Text="&#xE945;" FontFamily="Segoe MDL2 Assets"
                                       Foreground="{DynamicResource Brush_Accent}" FontSize="20"
                                       VerticalAlignment="Center" Margin="0,0,10,0"/>
                            <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
                                <TextBlock Text="SETT OPTIMIZER" Foreground="{DynamicResource Brush_TextPrimary}"
                                           FontSize="13" FontWeight="Bold" HorizontalAlignment="Center"/>
                                <TextBlock Text="Dashboard v3.2" Foreground="{DynamicResource Brush_TextMuted}"
                                           FontSize="10" Margin="0,2,0,0" HorizontalAlignment="Center"/>
                            </StackPanel>
                        </StackPanel>
                    </Border>

                <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto"
                              Style="{x:Null}">
                    <!-- Margin="0,0,0,16" adds breathing room after the last expanded section (e.g.
                         "Your PC" > Energy) when scrolled all the way down, so it doesn't look glued
                         to the fixed Settings button right below the ScrollViewer. -->
                    <StackPanel x:Name="pnlNav" Margin="0,0,0,50">

                        <!-- QUICK section (always visible) -->
                        <Button x:Name="hdrQuick" Style="{StaticResource NavHeaderStyle}" IsEnabled="False">
                            <TextBlock x:Name="txtHdrQuick" Text="QUICK"/>
                        </Button>
                    <Button x:Name="navHome" Style="{StaticResource NavButtonStyle}" Tag="pageHome">
                        <StackPanel Orientation="Horizontal">
                            <TextBlock Text="&#xEA8A;" FontFamily="Segoe MDL2 Assets" FontSize="14" Margin="0,0,10,0" VerticalAlignment="Center"/>
                            <TextBlock Text="Home" VerticalAlignment="Center"/>
                        </StackPanel>
                    </Button>
                    <Button x:Name="navAll" Style="{StaticResource NavButtonStyle}" Tag="pageAll">
                        <StackPanel Orientation="Horizontal">
                            <TextBlock Text="&#xE777;" FontFamily="Segoe MDL2 Assets" FontSize="14" Margin="0,0,10,0" VerticalAlignment="Center"/>
                            <TextBlock Text="Optimize All" VerticalAlignment="Center"/>
                        </StackPanel>
                    </Button>
                    <Button x:Name="navClean" Style="{StaticResource NavButtonStyle}" Tag="pageClean">
                        <StackPanel Orientation="Horizontal">
                            <TextBlock Text="&#xE74D;" FontFamily="Segoe MDL2 Assets" FontSize="14" Margin="0,0,10,0" VerticalAlignment="Center"/>
                            <TextBlock Text="Clean" VerticalAlignment="Center"/>
                        </StackPanel>
                    </Button>
                    <Button x:Name="navNetwork" Style="{StaticResource NavButtonStyle}" Tag="pageNetwork">
                        <StackPanel Orientation="Horizontal">
                            <TextBlock Text="&#xE839;" FontFamily="Segoe MDL2 Assets" FontSize="14" Margin="0,0,10,0" VerticalAlignment="Center"/>
                            <TextBlock Text="Network" VerticalAlignment="Center"/>
                        </StackPanel>
                    </Button>
                        <!-- YOUR PC section (collapsible) -->
                        <Button x:Name="hdrYourPC" Style="{StaticResource NavHeaderStyle}">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock x:Name="iconHdrYourPC" Text="&#xE76C;" FontFamily="Segoe MDL2 Assets" FontSize="9" Margin="0,0,8,0" VerticalAlignment="Center"/>
                                <TextBlock x:Name="txtHdrYourPC" Text="YOUR PC" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                        <StackPanel x:Name="secYourPC" Visibility="Collapsed">
                            <Button x:Name="navYourPCSystem" Style="{StaticResource NavButtonStyle}" Tag="pageYourPCSystem">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#xE770;" FontFamily="Segoe MDL2 Assets" FontSize="14" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="System" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="navYourPCSensors" Style="{StaticResource NavButtonStyle}" Tag="pageYourPCSensors">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#xE9CA;" FontFamily="Segoe MDL2 Assets" FontSize="14" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Sensors" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="navYourPCGpu" Style="{StaticResource NavButtonStyle}" Tag="pageYourPCGpu">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#xE7F4;" FontFamily="Segoe MDL2 Assets" FontSize="14" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="GPU" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="navYourPCCpu" Style="{StaticResource NavButtonStyle}" Tag="pageYourPCCpu">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#xE950;" FontFamily="Segoe MDL2 Assets" FontSize="14" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="CPU" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="navYourPCDisks" Style="{StaticResource NavButtonStyle}" Tag="pageYourPCDisks">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#xEDA2;" FontFamily="Segoe MDL2 Assets" FontSize="14" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Disks" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="navYourPCEnergy" Style="{StaticResource NavButtonStyle}" Tag="pageYourPCEnergy">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#xE945;" FontFamily="Segoe MDL2 Assets" FontSize="14" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Energy" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>
                        </StackPanel>

                        <!-- INSTALLERS section (collapsible) -->
                        <Button x:Name="hdrInstallers" Style="{StaticResource NavHeaderStyle}">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock x:Name="iconHdrInstallers" Text="&#xE76C;" FontFamily="Segoe MDL2 Assets" FontSize="9" Margin="0,0,8,0" VerticalAlignment="Center"/>
                                <TextBlock x:Name="txtHdrInstallers" Text="INSTALLERS" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                        <StackPanel x:Name="secInstallers" Visibility="Collapsed">
                            <Button x:Name="navInstallers" Style="{StaticResource NavButtonStyle}" Tag="pageInstallers">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#xE7B8;" FontFamily="Segoe MDL2 Assets" FontSize="14" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Essentials" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="navGpuProgs" Style="{StaticResource NavButtonStyle}" Tag="pageGpuSoftware">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#xE7F4;" FontFamily="Segoe MDL2 Assets" FontSize="14" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="GPU Software" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="navCpuProgs" Style="{StaticResource NavButtonStyle}" Tag="pageCpuSoftware">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#xE770;" FontFamily="Segoe MDL2 Assets" FontSize="14" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="CPU Software" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="navAllInstallers" Style="{StaticResource NavButtonStyle}" Tag="pageAllInstallers">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#xE71D;" FontFamily="Segoe MDL2 Assets" FontSize="14" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="ALL Programs" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>
                        </StackPanel>

                        <!-- SYSTEM section (collapsible) -->
                        <Button x:Name="hdrSystem" Style="{StaticResource NavHeaderStyle}">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock x:Name="iconHdrSystem" Text="&#xE76C;" FontFamily="Segoe MDL2 Assets" FontSize="9" Margin="0,0,8,0" VerticalAlignment="Center"/>
                                <TextBlock x:Name="txtHdrSystem" Text="SYSTEM" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                        <StackPanel x:Name="secSystem" Visibility="Collapsed">
                            <Button x:Name="navPerformance" Style="{StaticResource NavButtonStyle}" Tag="pagePerformance">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#xE7E8;" FontFamily="Segoe MDL2 Assets" FontSize="14" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Performance" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="navNetworkPrivacy" Style="{StaticResource NavButtonStyle}" Tag="pageNetworkPrivacy">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#xE774;" FontFamily="Segoe MDL2 Assets" FontSize="14" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Network &amp; Privacy" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="navSystemTweaks" Style="{StaticResource NavButtonStyle}" Tag="pageSystemTweaksAll">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#xE713;" FontFamily="Segoe MDL2 Assets" FontSize="14" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="System Tweaks" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="navWindows" Style="{StaticResource NavButtonStyle}" Tag="pageWindows">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#xE770;" FontFamily="Segoe MDL2 Assets" FontSize="14" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Windows Tweaks" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>
                        </StackPanel>

                        <!-- TOOLS section (collapsible) -->
                        <Button x:Name="hdrShortcuts" Style="{StaticResource NavHeaderStyle}">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock x:Name="iconHdrShortcuts" Text="&#xE76C;" FontFamily="Segoe MDL2 Assets" FontSize="9" Margin="0,0,8,0" VerticalAlignment="Center"/>
                                <TextBlock x:Name="txtHdrShortcuts" Text="SHORTCUTS" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
            <StackPanel x:Name="secShortcuts" Visibility="Collapsed">
                <Button x:Name="navWinShortcuts" Style="{StaticResource NavButtonStyle}" Tag="pageWinShortcuts">
                    <StackPanel Orientation="Horizontal">
                        <TextBlock Text="&#xE713;" FontFamily="Segoe MDL2 Assets" FontSize="14" Margin="0,0,10,0" VerticalAlignment="Center"/>
                        <TextBlock Text="Windows Config" VerticalAlignment="Center"/>
                    </StackPanel>
                </Button>
            </StackPanel>

            <Button x:Name="hdrTools" Style="{StaticResource NavHeaderStyle}">
                <StackPanel Orientation="Horizontal">
                    <TextBlock x:Name="iconHdrTools" Text="&#xE76C;" FontFamily="Segoe MDL2 Assets" FontSize="9" Margin="0,0,8,0" VerticalAlignment="Center"/>
                    <TextBlock x:Name="txtHdrTools" Text="TOOLS" VerticalAlignment="Center"/>
                </StackPanel>
            </Button>
                        <StackPanel x:Name="secTools" Visibility="Collapsed">
                            <Button x:Name="navUtilities" Style="{StaticResource NavButtonStyle}" Tag="pageUtilities">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#xEA99;" FontFamily="Segoe MDL2 Assets" FontSize="14" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Utilities" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="navPlaybooks" Style="{StaticResource NavButtonStyle}" Tag="pagePlaybooks">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#xE753;" FontFamily="Segoe MDL2 Assets" FontSize="14" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Playbooks Download" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>
                        </StackPanel>

                        <!-- BENCHMARK section (collapsible) -->
                        <Button x:Name="hdrBenchmark" Style="{StaticResource NavHeaderStyle}">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock x:Name="iconHdrBenchmark" Text="&#xE76C;" FontFamily="Segoe MDL2 Assets" FontSize="9" Margin="0,0,8,0" VerticalAlignment="Center"/>
                                <TextBlock x:Name="txtHdrBenchmark" Text="BENCHMARK" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                        <StackPanel x:Name="secBenchmark" Visibility="Collapsed">
                            <Button x:Name="navBenchCpu" Style="{StaticResource NavButtonStyle}" Tag="pageBenchCpu">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#xE950;" FontFamily="Segoe MDL2 Assets" FontSize="14" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="CPU" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="navBenchGpu" Style="{StaticResource NavButtonStyle}" Tag="pageBenchGpu">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#xE7F4;" FontFamily="Segoe MDL2 Assets" FontSize="14" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="GPU" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="navBenchRam" Style="{StaticResource NavButtonStyle}" Tag="pageBenchRam">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#xE7F8;" FontFamily="Segoe MDL2 Assets" FontSize="14" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="RAM" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="navBenchDisk" Style="{StaticResource NavButtonStyle}" Tag="pageBenchDisk">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#xEDA2;" FontFamily="Segoe MDL2 Assets" FontSize="14" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Disk" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="navBenchExport" Style="{StaticResource NavButtonStyle}" Tag="pageBenchExport">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#xE9F9;" FontFamily="Segoe MDL2 Assets" FontSize="14" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Export" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>
                        </StackPanel>

                    </StackPanel>
                </ScrollViewer>

                    <!-- Settings pinned to the bottom of the sidebar, like a fixed "exit" button.
                         Margin="0,10,0,0" adds breathing room so it doesn't look glued to the last
                         "Your PC" item right above it. -->
                    <Border Grid.Row="2" BorderBrush="{DynamicResource Brush_Border}" BorderThickness="0,1,0,0" Margin="0,10,0,0">
                        <Button x:Name="navSettings" Style="{StaticResource NavButtonStyle}" Tag="pageSettings" Margin="10,10,10,6">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock Text="&#xE713;" FontFamily="Segoe MDL2 Assets" FontSize="14" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                <TextBlock Text="Settings" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                    </Border>
                </Grid>
            </Border>

            <!-- ==================== RIGHT CONTENT AREA ==================== -->
            <Grid Grid.Column="1">
                <Grid.RowDefinitions>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="5"/>
                    <RowDefinition x:Name="rowLogContainer" Height="175"/>
                </Grid.RowDefinitions>

                <!-- Page content scroll area -->
                <ScrollViewer Grid.Row="0" VerticalScrollBarVisibility="Auto">
                    <StackPanel x:Name="pnlContent" Margin="24,12,24,0">
                        <!-- Pages are injected here at runtime by PowerShell -->
                    </StackPanel>
                </ScrollViewer>

                <!-- Drag handle to resize the log panel -->
                <GridSplitter Grid.Row="1" HorizontalAlignment="Stretch" VerticalAlignment="Stretch"
                              Height="5" Background="{DynamicResource Brush_TitleBarBg}" ResizeDirection="Rows" Cursor="SizeNS"/>

                <!-- ==================== BOTTOM BAR ==================== -->
                <Border Grid.Row="2" Background="{DynamicResource Brush_TitleBarBg}"
                        BorderBrush="{DynamicResource Brush_Border}" BorderThickness="0,1,0,0"
                        Padding="12,8">
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>

                        <ProgressBar Grid.Row="0" x:Name="progressBar"
                                     Style="{StaticResource ProgressBarStyle}"
                                     Minimum="0" Maximum="100" Value="0"
                                     HorizontalAlignment="Stretch"
                                     Margin="0,0,0,6"/>

                        <Grid Grid.Row="1" Margin="0,2,0,4">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Grid.Column="0" Text="LOG" Foreground="{DynamicResource Brush_TextMuted}"
                                       FontFamily="{DynamicResource Theme_FontFamily}"
                                       FontSize="10" FontWeight="Bold" VerticalAlignment="Center"/>
                            <StackPanel Grid.Column="1" Orientation="Horizontal">
                                <Button x:Name="btnLogCopy" Content="&#xE8C8;" ToolTip="Copy log"
                                        Style="{StaticResource LogIconButtonStyle}" Margin="0,0,2,0"/>
                                <Button x:Name="btnLogClear" Content="&#xE74D;" ToolTip="Clear log"
                                        Style="{StaticResource LogIconButtonStyle}"/>
                            </StackPanel>
                        </Grid>

                        <RichTextBox Grid.Row="2" x:Name="txtLog" Style="{StaticResource LogBoxStyle}"
                                     Background="{DynamicResource Brush_LogBg}" Foreground="{DynamicResource Brush_LogText}"
                                     CaretBrush="{DynamicResource Brush_LogText}"
                                     FontFamily="{DynamicResource Theme_FontFamily}" FontSize="11"
                                     IsReadOnly="True" VerticalScrollBarVisibility="Auto">
                            <RichTextBox.Resources>
                                <Style TargetType="Paragraph">
                                    <Setter Property="Margin" Value="0"/>
                                    <Setter Property="LineHeight" Value="16"/>
                                </Style>
                            </RichTextBox.Resources>
                        </RichTextBox>
                    </Grid>
                </Border>
            </Grid>
        </Grid>

        <!-- ==================== RETRO CRT SCANLINE OVERLAY ====================
             Hidden by default (Default theme). Set-GuiTheme toggles its Visibility
             to Visible only when the Terminal Retro theme is active, giving the
             whole window a subtle horizontal-scanline CRT look without affecting
             hit-testing (IsHitTestVisible="False") or any existing functionality. -->
        <Border x:Name="RetroScanlineOverlay" Grid.RowSpan="2" IsHitTestVisible="False"
                Visibility="Collapsed" Opacity="0.35">
            <Border.Background>
                <DrawingBrush TileMode="Tile" Viewport="0,0,1,4" ViewportUnits="Absolute" Stretch="None">
                    <DrawingBrush.Drawing>
                        <GeometryDrawing Brush="#1A000000">
                            <GeometryDrawing.Geometry>
                                <RectangleGeometry Rect="0,0,4,2"/>
                            </GeometryDrawing.Geometry>
                        </GeometryDrawing>
                    </DrawingBrush.Drawing>
                </DrawingBrush>
            </Border.Background>
        </Border>
    </Grid>

</Window>
"@
#endregion

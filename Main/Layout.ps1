#region XAML DASHBOARD LAYOUT
[xml]$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Width="1200" Height="740"
    WindowStyle="None"
    AllowsTransparency="True"
    Background="#0D1117"
    BorderBrush="#30363D"
    BorderThickness="1"
    ResizeMode="CanResizeWithGrip"
    TextOptions.TextFormattingMode="Display"
    TextOptions.TextRenderingMode="Grayscale"
    UseLayoutRounding="True"
    RenderOptions.ClearTypeHint="Enabled">

    <Window.Resources>
        <!-- ==================== NAV BUTTON STYLE ==================== -->
        <Style x:Key="NavButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="#8B949E"/>
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
                                CornerRadius="5">
                            <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
                                              VerticalAlignment="Center"
                                              TextBlock.Foreground="{TemplateBinding Foreground}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#161B22"/>
                                <Setter Property="Foreground" Value="#E6EDF3"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#1C2128"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ==================== NAV BUTTON ACTIVE STYLE ==================== -->
        <Style x:Key="NavButtonActiveStyle" TargetType="Button">
            <Setter Property="Background" Value="#14181F"/>
            <Setter Property="Foreground" Value="#E6EDF3"/>
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
                                    CornerRadius="5">
                                <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
                                                  VerticalAlignment="Center"
                                                  TextBlock.Foreground="{TemplateBinding Foreground}"/>
                            </Border>
                            <Border Width="3" HorizontalAlignment="Left" Background="#58A6FF" CornerRadius="0,2,2,0" Margin="-10,4,0,4"/>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#1A1F27"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ==================== NAV HEADER STYLE ==================== -->
        <Style x:Key="NavHeaderStyle" TargetType="Button">
            <Setter Property="Foreground" Value="#6E7681"/>
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
                                <Setter Property="Foreground" Value="#8B949E"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ==================== ACTION BUTTON STYLE ==================== -->
        <Style x:Key="ActionButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="#C9D1D9"/>
            <Setter Property="FontSize" Value="11"/>
            <Setter Property="FontWeight" Value="Normal"/>
            <Setter Property="MinHeight" Value="28"/>
            <Setter Property="MinWidth" Value="0"/>
            <Setter Property="Width" Value="Auto"/>
            <Setter Property="Padding" Value="10,0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="#30363D"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                Padding="{TemplateBinding Padding}"
                                CornerRadius="6"
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
                                <Setter TargetName="border" Property="BorderBrush" Value="#F0883E"/>
                                <Setter Property="Foreground" Value="#F0883E"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#161B22"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="BorderBrush" Value="#21262D"/>
                                <Setter Property="Foreground" Value="#484F58"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ==================== REVERT BUTTON STYLE ==================== -->
        <Style x:Key="RevertButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="#C9D1D9"/>
            <Setter Property="FontSize" Value="11"/>
            <Setter Property="FontWeight" Value="Normal"/>
            <Setter Property="MinHeight" Value="28"/>
            <Setter Property="MinWidth" Value="0"/>
            <Setter Property="Width" Value="Auto"/>
            <Setter Property="Padding" Value="10,0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="#30363D"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                Padding="{TemplateBinding Padding}"
                                CornerRadius="6"
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
                                <Setter TargetName="border" Property="BorderBrush" Value="#F85149"/>
                                <Setter Property="Foreground" Value="#F85149"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#161B22"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="BorderBrush" Value="#21262D"/>
                                <Setter Property="Foreground" Value="#484F58"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ==================== DANGER BUTTON STYLE ==================== -->
        <Style x:Key="DangerButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="#6E2C2C"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontSize" Value="11"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="MinHeight" Value="28"/>
            <Setter Property="MinWidth" Value="0"/>
            <Setter Property="Width" Value="Auto"/>
            <Setter Property="Padding" Value="10,0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}"
                                Padding="{TemplateBinding Padding}"
                                CornerRadius="8"
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
                                <Setter TargetName="border" Property="Background" Value="#F85149"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#A32D2A"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="Background" Value="#21262D"/>
                                <Setter Property="Foreground" Value="#484F58"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ==================== TOOL BUTTON STYLE ==================== -->
        <Style x:Key="ToolButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="#C9D1D9"/>
            <Setter Property="FontSize" Value="11"/>
            <Setter Property="MinHeight" Value="26"/>
            <Setter Property="MinWidth" Value="0"/>
            <Setter Property="Padding" Value="10,0"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="#30363D"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="6" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="BorderBrush" Value="#F0883E"/>
                                <Setter Property="Foreground" Value="#F0883E"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#161B22"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ==================== CARD STYLE ==================== -->
        <Style x:Key="CardStyle" TargetType="Border">
            <Setter Property="Background" Value="#11151B"/>
            <Setter Property="BorderBrush" Value="#21262D"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CornerRadius" Value="8"/>
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
                    <Setter Property="BorderBrush" Value="#3C444D"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <!-- ==================== CARD TITLE STYLE ==================== -->
        <Style x:Key="CardTitleStyle" TargetType="TextBlock">
            <Setter Property="Foreground" Value="#E6EDF3"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Margin" Value="0,0,0,4"/>
        </Style>

        <!-- ==================== CARD DESCRIPTION STYLE ==================== -->
        <Style x:Key="CardDescStyle" TargetType="TextBlock">
            <Setter Property="Foreground" Value="#8B949E"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="LineHeight" Value="17"/>
            <Setter Property="TextWrapping" Value="Wrap"/>
            <Setter Property="Margin" Value="0,0,0,14"/>
        </Style>

        <!-- ==================== SECTION LABEL STYLE (minimal eyebrow) ==================== -->
        <Style x:Key="SectionLabelStyle" TargetType="TextBlock">
            <Setter Property="Foreground" Value="#6E7681"/>
            <Setter Property="FontSize" Value="11"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Margin" Value="0,0,0,10"/>
        </Style>

        <!-- ==================== PAGE TITLE STYLE ==================== -->
        <Style x:Key="PageTitleStyle" TargetType="TextBlock">
            <Setter Property="Foreground" Value="#E6EDF3"/>
            <Setter Property="FontSize" Value="20"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Margin" Value="0,0,0,12"/>
        </Style>

        <!-- ==================== PROGRESS BAR STYLE ==================== -->
        <Style x:Key="ProgressBarStyle" TargetType="ProgressBar">
            <Setter Property="Height" Value="10"/>
            <Setter Property="Background" Value="#21262D"/>
            <Setter Property="Foreground" Value="#1F6FEB"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ProgressBar">
                        <Grid>
                            <Border Background="{TemplateBinding Background}"
                                    CornerRadius="3" BorderThickness="0"/>
                            <Border x:Name="PART_Track" Background="Transparent"
                                    CornerRadius="3" BorderThickness="0">
                                <Border x:Name="PART_Indicator" Background="{TemplateBinding Foreground}"
                                        CornerRadius="3" BorderThickness="0"
                                        HorizontalAlignment="Left"/>
                            </Border>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ==================== CLOSE BUTTON STYLE ==================== -->
        <Style x:Key="CloseButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="#8B949E"/>
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
                                <Setter TargetName="border" Property="Background" Value="#DA3633"/>
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
            <Setter Property="Foreground" Value="#8B949E"/>
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
                                <Setter TargetName="border" Property="Background" Value="#30363D"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ==================== LOG ICON BUTTON STYLE ==================== -->
        <Style x:Key="LogIconButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="#6E7681"/>
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
                                <Setter TargetName="border" Property="Background" Value="#21262D"/>
                                <Setter Property="Foreground" Value="#E6EDF3"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ==================== SCROLLBAR STYLE ==================== -->
        <Style x:Key="ScrollBarStyle" TargetType="ScrollBar">
            <Setter Property="Width" Value="8"/>
            <Setter Property="Background" Value="#161B22"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ScrollBar">
                        <Border Background="{TemplateBinding Background}" CornerRadius="4">
                            <Track x:Name="PART_Track" IsDirectionReversed="True">
                                <Track.Thumb>
                                    <Thumb Background="#30363D" BorderThickness="0" Width="6">
                                        <Thumb.Template>
                                            <ControlTemplate TargetType="Thumb">
                                                <Border Background="{TemplateBinding Background}" CornerRadius="4"/>
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
                                                <Border x:Name="ThumbBorder" Background="#30363D" CornerRadius="3.5" Margin="1,0" Width="5">
                                                    <Border.RenderTransform>
                                                        <ScaleTransform x:Name="ThumbScale" ScaleX="1"/>
                                                    </Border.RenderTransform>
                                                </Border>
                                                <ControlTemplate.Triggers>
                                                    <Trigger Property="IsMouseOver" Value="True">
                                                        <Setter TargetName="ThumbBorder" Property="Background" Value="#1F6FEB"/>
                                                        <Setter TargetName="ThumbBorder" Property="Width" Value="7"/>
                                                    </Trigger>
                                                    <Trigger Property="IsDragging" Value="True">
                                                        <Setter TargetName="ThumbBorder" Property="Background" Value="#388BFD"/>
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

    </Window.Resources>

    <!-- ==================== ROOT GRID ==================== -->
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="32"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <!-- ==================== TITLE BAR ==================== -->
        <Border Grid.Row="0" x:Name="titleBar" Background="#161B22"
                BorderBrush="#30363D" BorderThickness="0,0,0,1">
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
            <Border Grid.Column="0" Background="#0D1117"
                    BorderBrush="#30363D" BorderThickness="0,0,1,0">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>

                    <!-- Sidebar brand header -->
                    <Border Grid.Row="0" Background="#0D1117"
                            BorderBrush="#30363D" BorderThickness="0,0,0,1"
                            Padding="14,16,14,16">
                        <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                            <TextBlock Text="&#xE945;" FontFamily="Segoe MDL2 Assets"
                                       Foreground="#1F6FEB" FontSize="20"
                                       VerticalAlignment="Center" Margin="0,0,10,0"/>
                            <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
                                <TextBlock Text="SETT OPTIMIZER" Foreground="#E6EDF3"
                                           FontSize="13" FontWeight="Bold" HorizontalAlignment="Center"/>
                                <TextBlock Text="Dashboard v3.2" Foreground="#6E7681"
                                           FontSize="10" Margin="0,2,0,0" HorizontalAlignment="Center"/>
                            </StackPanel>
                        </StackPanel>
                    </Border>

                <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto"
                              Style="{x:Null}">
                    <StackPanel x:Name="pnlNav">

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

                    </StackPanel>
                </ScrollViewer>
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
                              Height="5" Background="#161B22" ResizeDirection="Rows" Cursor="SizeNS"/>

                <!-- ==================== BOTTOM BAR ==================== -->
                <Border Grid.Row="2" Background="#161B22"
                        BorderBrush="#30363D" BorderThickness="0,1,0,0"
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
                            <TextBlock Grid.Column="0" Text="LOG" Foreground="#6E7681"
                                       FontSize="10" FontWeight="Bold" VerticalAlignment="Center"/>
                            <StackPanel Grid.Column="1" Orientation="Horizontal">
                                <Button x:Name="btnLogCopy" Content="&#xE8C8;" ToolTip="Copy log"
                                        Style="{StaticResource LogIconButtonStyle}" Margin="0,0,2,0"/>
                                <Button x:Name="btnLogClear" Content="&#xE74D;" ToolTip="Clear log"
                                        Style="{StaticResource LogIconButtonStyle}"/>
                            </StackPanel>
                        </Grid>

                        <RichTextBox Grid.Row="2" x:Name="txtLog" Background="#0D1117" Foreground="#8B949E"
                                     BorderBrush="#30363D" BorderThickness="1"
                                     FontFamily="Consolas" FontSize="11"
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
    </Grid>

</Window>
"@
#endregion

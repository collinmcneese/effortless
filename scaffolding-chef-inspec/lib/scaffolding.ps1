#
# A scaffolding for an InSpec profile
#

function Load-Scaffolding {
    $pkg_deps += @(
        "${pkg_deps[@]}"
        "stuartpreston/inspec"
    )
    $pkg_build_deps += @(
        "${pkg_build_deps[@]}"
        "stuartpreston/inspec"
    )

    $pkg_svc_user="administrator"
    $pkg_svc_run = "set_just_so_you_will_render"
}

function Invoke-DefaultBefore {
    if(!(Test-Path "$PLAN_CONTEXT/../inspec.yml")) {
        Write-BuildLine "Error: Cannot find inspec.yml"
        Write-BuildLine "  Please build from the profile root"
        exit 1
    }

    if((Select-String -Path "$PLAN_CONTEXT/../inspec.yml" -Pattern "compliance: ")){
        if(!$scaffold_automate_server_url){
            Write-BuildLine "You have a dependency on a profile in Automate"
            Write-BuildLine " please specify the `$scaffold_automate_server_url"
            Write-BuildLine " in your plan.ps1 file."
            exit 1
        }
        elseif(!$scaffold_automate_user){
            Write-BuildLine "You have a dependency on a profile in Automate"
            Write-BuildLine " please specify the `$scaffold_automate_user"
            Write-BuildLine " in your plan.ps1 file."
            exit 1
        }
        elseif(!$scaffold_automate_token){
            Write-BuildLine "You have a dependency on a profile in Automate"
            Write-BuildLine " please specify the `$scaffold_automate_token"
            Write-BuildLine " in your plan.ps1 file."
            exit 1
        }
        else{
            inspec compliance login "$scaffold_automate_server_url" `
                            --user "$scaffold_automate_user" `
                            --token "$scaffold_automate_token"
        }
    }
}

function Invoke-DefaultSetupEnvironment {
    Set-BuildtimeEnv $PROFILE_CACHE_DIR "$HAB_CACHE_SRC_PATH/$pkg_dirname"
    Set-BuildtimeEnv $ARCHIVE_NAME "$pkg_name-$pkg_version.tar.gz"
}

function Invoke-DefaultUnpack {
    New-Item -ItemType Directory -Path "$HAB_CACHE_SRC_PATH/$pkg_dirname"
    Copy-Item $PLAN_CONTEXT/../* "$HAB_CACHE_SRC_PATH/$pkg_dirname" -Exclude habitat,results,*.harts -Recurse -Force
}

function Invoke-DefaultBuildService {
    Write-BuildLine "Creating lifecycle hooks"
    New-Item -ItemType Directory -Path "$pkg_prefix/hooks"

    Add-Content -Path "$pkg_prefix/hooks/run" -Value @"
`$env:PATH = "{{pkgPathFor "stuartpreston/inspec"}}/bin;`$env:PATH"

`$env:CFG_SPLAY_FIRST_RUN="{{cfg.splay_first_run}}"
if(!`$env:CFG_SPLAY_FIRST_RUN) {
    `$env:CFG_SPLAY_FIRST_RUN = "0"
}

`$env:CFG_INTERVAL="{{cfg.interval}}"
if(!`$env:CFG_INTERVAL){
    `$env:CFG_INTERVAL = "1800"
}

`$env:CFG_SPLAY="{{cfg.splay}}"
if(!`$env:CFG_SPLAY){
    `$env:CFG_SPLAY = "1800"
}

`$env:CFG_LOG_LEVEL="{{cfg.log_level}}"
if (!`$env:CFG_LOG_LEVEL){
    `$env:CFG_LOG_LEVEL = "warn"
}

`$env:CFG_CHEF_LICENSE="{{cfg.chef_license.acceptance}}"
if(!`$env:CFG_CHEF_LICENSE){
    `$env:CFG_CHEF_LICENSE = "undefined"
}

`$CONFIG="{{pkg.svc_config_path}}/inspec_exec_config.json"
`$PROFILE_PATH="{{pkg.path}}/{{pkg.name}}-{{pkg.version}}.tar.gz"

function Invoke-Inspec {

    # TODO: This is set to --json-config due to the
    #  version of InSpec being used please update when InSpec is updated

    inspec exec `$PROFILE_PATH --json-config `$CONFIG --log-level `$env:CFG_LOG_LEVEL
}

`$SPLAY_DURATION = Get-Random -InputObject (0..`$env:CFG_SPLAY) -Count 1

`$SPLAY_FIRST_RUN_DURATION = Get-Random -InputObject (0..`$env:CFG_SPLAY_FIRST_RUN) -Count 1

Start-Sleep -Seconds `$SPLAY_FIRST_RUN_DURATION
Invoke-Inspec

while(`$true){
  `$SLEEP_TIME = `$SPLAY_DURATION + `$env:CFG_INTERVAL
  Write-Host "InSpec is sleeping for `$SLEEP_TIME seconds"
  Start-Sleep -Seconds `$SPLAY_DURATION
  Start-Sleep -Seconds `$env:CFG_INTERVAL
  Invoke-Inspec
}
"@
}

function Invoke-DefaultBuild {
    inspec archive "$HAB_CACHE_SRC_PATH/$pkg_dirname" `
                   --overwrite `
                   -o "$HAB_CACHE_SRC_PATH/$pkg_dirname/$pkg_name-$pkg_version.tar.gz"
}

function Invoke-DefaultInstall {
    Copy-Item "$HAB_CACHE_SRC_PATH/$pkg_dirname/$pkg_name-$pkg_version.tar.gz" "$pkg_prefix"
    New-Item -Type Directory $pkg_prefix/config

    Write-BuildLine "Generating config/cli_only.json"
    Add-Content -Path "$pkg_prefix/config/cli_only.json" -Value @"
{
    "reporter": {
        "cli" : {
            "stdout" : true
        }
    }
}
"@

    Write-BuildLine "Generating config/inspec_exec_config.json"
    Add-Content -Path "$pkg_prefix/config/inspec_exec_config.json" -Value @"
{
    "target_id": "{{ sys.member_id }}",
    "reporter": {
        "cli": {
          "stdout": true
        }{{#if cfg.automate.enable ~}},
        "automate" : {
          "url": "{{cfg.automate.server_url}}/data-collector/v0/",
          "token": "{{cfg.automate.token}}",
          "node_name": "{{ sys.hostname }}",
          "verify_ssl": false
        }{{/if ~}}
    }
}
"@

    Write-BuildLine "Generating Chef Habitat configuration default.toml"
    Add-Content -Path "$pkg_prefix/default.toml" -Value @"
# You must accept the Chef License to use this software: https://www.chef.io/end-user-license-agreement/
# Change [chef_license] from acceptance = "undefined" to acceptance = "accept-no-persist" if you agree to the license.

interval = 1800
splay = 1800
splay_first_run = 0
log_level = 'warn'

[chef_license]
acceptance = "undefined"

[automate]
enable = false
server_url = 'https://<automate_url>'
token = '<automate_token>'
user = '<automate_user>'
"@
}
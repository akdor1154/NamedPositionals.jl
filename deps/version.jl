using Pkg
using ArgParse

# version bump script because i don't like how PkgDev does branching.
# todo: rewrite in python and move to separate package
# (julia lacks CLI script installs and keyring management)

@enum VersionComponent begin
    patch
    minor
    major
end

function getArgs()
    s = ArgParseSettings(autofix_names = true)

    versionTypes = instances(VersionComponent) .|> string

    @add_arg_table! s begin
        "version_type"
            range_tester = (s -> s ∈ versionTypes)
            required = false
            help = "version_type, must be " * join(versionTypes, ", ", ", or ")
        "--no-act", "-n"
            action = :store_true
        "--no-bump"
            action = :store_true
    end

    parse_args(ARGS, s; as_symbols=true)
end

function ensureMaster()
    headHash = read(`git rev-parse HEAD`, String) |> strip
    masterHash = read(`git rev-parse master`, String) |> strip
    if headHash != masterHash
        error("Head $(headHash) != master $(masterHash). You probably want to `git checkout master`.")
    end
end

function getTomlAndEnsureRoot()
    p = "Project.toml"
    if !isfile(p)
        error("You don't seem to be in a project. Project.toml not found.")
    end
    toml = Pkg.TOML.parsefile(p)
    println("Running on package $(toml["name"]), current version $(toml["version"])")
    return (
        toml = Pkg.TOML.parsefile(p),
        path=p
    )
end

function getWantedVersion(versionType::VersionComponent, toml) :: VersionNumber
    v = VersionNumber(toml["version"])
    if versionType == patch
        return VersionNumber(v.major, v.minor, v.patch+1)
    elseif versionType == minor
        return VersionNumber(v.major, v.minor+1, 0)
    elseif versionType == major
        return VersionNumber(v.major+1, 0, 0)
    else
        dump(versionType)
        error("Unknown version component")
    end
end

function updateVersionInTomlAct(toml, tomlpath::String, wantedVersion::VersionNumber)
    toml["version"] = wantedVersion

    open(tomlpath, "w") do f
        Pkg.TOML.print(f, toml)
    end
end

function updateVersionInTomlNoAct(toml, tomlpath::String, wantedVersion:: VersionNumber)
    println("Would update version from $(toml["version"]) -> $(wantedVersion)")
end

function commitAct(newVersion, tomlpath::String) :: String
    run(`git commit -m "v$(newVersion)" $(tomlpath)`)
end

function commitNoAct(newVersion, tomlpath::String) :: String
    println("Would commit now.")
end

function tagAct(newVersion)
    run(`git tag -am "v$(newVersion) candidate" "candidate_v$(newVersion)"`)
end

function tagNoAct(newVersion)
    println(`git tag -am "v$(newVersion) candidate" "candidate_v$(newVersion)"`)
end

function main()
    args = getArgs()

    act::Bool = !args[:no_act]
    bump::Bool = !args[:no_bump]

    updateVersion = (act) ? updateVersionInTomlAct : updateVersionInTomlNoAct
    commit = (act) ? commitAct : commitNoAct
    tag = (act) ? tagAct : tagNoAct

    toml, tomlpath = getTomlAndEnsureRoot()
    
    local newVersion::VersionNumber
    if bump
        versionType = convert(VersionComponent, args[:version_type])
        ensureMaster()
        newVersion = getWantedVersion(versionType, toml)
        updateVersion(toml, tomlpath, newVersion)
        commit(newVersion, tomlpath)
    else
        newVersion = VersionNumber(toml["version"])
    end

    tag(newVersion)

end

# util

function convert(t::Type{VersionComponent}, x::AbstractString) :: VersionComponent
    values = instances(t)
    strings = values .|> string
    pairs = zip(values, strings)
    firstmatch = first([
        val
        for (val, s) in pairs
        if s == x
    ])
    return firstmatch
end


main()
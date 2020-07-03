using Pkg
using ArgParse
import GitHub
using URIParser

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
            help = "version_type, must be " * join(versionTypes, ", ", ", or ")
        "--no-act", "-n"
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

function commitAndPushMasterAct(newVersion, tomlpath::String) :: String
    run(`git commit -m "v$(newVersion)" $(tomlpath)`)
    run(`git push`)

    headHash = read(`git rev-parse HEAD`, String) |> strip
    return headHash
end

function commitAndPushMasterNoAct(newVersion, tomlpath::String) :: String
    println("Would commit and push master now.")

    headHash = read(`git rev-parse HEAD`, String) |> strip
    return headHash
end

function authGithub() :: GitHub.Authorization
    githubToken = 
        try
            read(`keyring get github api`, String) |> chomp
        catch
            error(
                "Could\'t read github token. Go to \n" *
                "https://github.com/settings/tokens/new ,\n" *
                "and then set your token using" *
                "`keyring set github api`."
            )
        end
    GitHub.authenticate(githubToken)
end

function getRepo(auth::GitHub.Authorization) :: GitHub.Repo
    remote:: String = read(`git remote get-url origin`, String) |> strip
    path = let
        if occursin("://", remote)
            uri = URI(remote)
            uri.path
        else
            sshName, path = split(remote, ":"; limit=2)
            path
        end
    end
    pathArray = split(path, "/")

    user = pathArray[end-1]
    repo = pathArray[end]
    if endswith(repo, ".git")
        repo = repo[1:end-length(".git")]
    end

    fullName = "$(user)/$(repo)"
    ghRepo = GitHub.repo(fullName; auth=auth)
end

function _addRegistratorComment(auth::GitHub.Authorization, repo::GitHub.Repo, hash::String, body::String)
    comment = GitHub.create_comment(repo, hash, :commit; auth=auth, params=Dict("body" => body))
end

function addRegistratorCommentAct(auth::GitHub.Authorization, repo::GitHub.Repo, hash::String)
    comment = _addRegistratorComment(auth, repo, hash, "@JuliaRegistrator register")
    println(comment)
end

function addRegistratorCommentNoAct(repo::GitHub.Repo, hash::String)
    comment = _addRegistratorComment(auth, repo, hash, "_JuliaRegistrator register test")
    println(comment)
end

function main()
    args = getArgs()

    updateVersion = (args[:no_act]) ? updateVersionInTomlNoAct : updateVersionInTomlAct
    commitAndPushMaster = (args[:no_act]) ? commitAndPushMasterNoAct : commitAndPushMasterAct
    addRegistratorComment = (args[:no_act]) ? addRegistratorCommentNoAct : addRegistratorCommentAct
    auth = authGithub()
    repo = getRepo(auth)

    versionType = convert(VersionComponent, args[:version_type])
    toml, tomlpath = getTomlAndEnsureRoot()
    ensureMaster()
    newVersion = getWantedVersion(versionType, toml)
    updateVersion(toml, tomlpath, newVersion)
    hash = commitAndPushMaster(newVersion, tomlpath)
    addRegistratorComment(auth, repo, hash)
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
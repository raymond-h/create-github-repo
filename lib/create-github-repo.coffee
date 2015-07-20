{CompositeDisposable} = require 'atom'
{exec} = require 'child_process'

Github = require 'github-api'
Q = require 'q'

module.exports =
    config:
        accessToken:
            title: 'GitHub access token'
            description: 'The OAuth access token used to access GitHub\'s API'
            type: 'string'
            default: ''

    activate: ->
        @disposables = new CompositeDisposable

        @disposables.add atom.commands.add 'atom-workspace',
            'create-github-repo:create-repo': =>
                @createRepository()

        @disposables.add atom.config.observe 'create-github-repo.accessToken',
            (token) =>
                @authenticateGithub token

    deactivate: ->
        @disposables.dispose()

    authenticateGithub: (token) ->
        github = new Github
            auth: 'oauth'
            token: token

        @user = github.getUser()

    createRepository: ->
        packageJson = @findPackageJson()

        packageJson.read()

        .then (str) -> JSON.parse str

        .then (data) =>
            Q.ninvoke @user, 'createRepo',
                name: data.name
                description: data.description

        .then ([res]) =>
            atom.notifications.addInfo "
                Created GitHub repo #{res.owner.login}/#{res.name}
            ", {
                detail: "URL: #{res.http_url}"
            }

            .then => @git 'remote', 'add', 'origin', res.git_url
            .then => @git 'push', 'origin', 'master'

            .then ([stdout]) =>
                atom.notifications.addSuccess "
                    Pushed `master` to repo #{res.owner.login}/#{res.name}
                ", {
                    detail: stdout
                }

        .catch (err) ->
            atom.notifications.addError err.name,
                detail: err.message
                stack: err.stack

    findPackageJson: ->
        dir = atom.project.getDirectories()[0]

        file = dir.getFile 'package.json'
        if file.existsSync() then file else null

    git: (params...) ->
        Q.nfcall exec,
            "git #{params.map((p) -> '"' + p + '"').join ' '}",
            cwd: atom.project.getRepositories()[0].getWorkingDirectory()

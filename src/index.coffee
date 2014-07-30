_ = require 'underscore'
Hoek = require 'hoek'
boom = require 'boom'

internals = {}

module.exports.register = (plugin, options = {}, cb) ->

  options = Hoek.applyToDefaults {clientId: null,accountId:null} , options

  internals.clientId = options.clientId
  internals.accountId = options.accountId

  Hoek.assert(internals.clientId, 'Missing required clientId property in hapi-auth-bearer-mw configuration');
  Hoek.assert(internals.accountId, 'Missing required accountId property in hapi-auth-bearer-mw configuration');

  
  internals.identityStore = plugin.plugins['hapi-identity-store']
  Hoek.assert internals.identityStore,"Could not access identity store. Make sure 'hapi-identity-store' is loaded as a plugin."

  internals.oauthAuth = -> internals.identityStore?.methods?.oauthAuth
  internals.users = -> internals.identityStore?.methods?.users

  Hoek.assert _.isFunction internals.oauthAuth, "No oauth auth accessible."
  Hoek.assert _.isFunction internals.users, "No users accessible."

  plugin.auth.scheme 'hapi-auth-bearer-mw', internals.bearer
  cb()

module.exports.register.attributes =
    pkg: require '../package.json'

internals.validateFunc = (secretOrToken, cb) ->

  internals.oauthAuth().validate secretOrToken,internals.clientId, {}, (err,infoResult) ->
    return cb err if err
    return cb null, null unless infoResult and infoResult.isValid # No token found, not authorized, check

    Hoek.assert infoResult.actor,"No actor present in token result"
    Hoek.assert infoResult.actor.actorId,"No actor id present in token result"

    credentials = 
      id: infoResult.actor.actorId
      clientId: infoResult.clientId
      isValid: !!infoResult.isValid
      isClientValid: !!infoResult.isClientValid
      scopes: infoResult.scopes
      expiresIn: infoResult.expiresIn
      token: secretOrToken #Important

    internals.users().get credentials.id,{}, (err,user) ->
      return cb err if err

      credentials.name = user.username
      credentials.user = user

      cb null, credentials
    #console.log JSON.stringify(infoResult)

    ###
                if (!info) {
                return cb(null, null);
              }
              info.isValid = !!(info.actor && info.actor.actorId && info.expiresIn);
              if (info.isValid) {
                user = {
                  isServerToken: false,
                  isActsAsActorId: false,
                  username: info.actor.actorId,
                  userId: info.actor.actorId,
                  scopes: []
                };
                _.extend(user, info);
                user.scopes.push('user');
                return cb(null, user);
              } else {
                return cb(null, null);

    ###



internals.bearer = (server, options) ->
  scheme =
    authenticate: (request, reply) ->
      #console.log "Checking authorization"
      req = request.raw.req
      authorization = req.headers.authorization
      return reply(boom.unauthorized(null, "Bearer"))  unless authorization
      #console.log "authorization found #{authorization}"

      parts = authorization.split(/\s+/)
      return reply(boom.badRequest("Bad HTTP authentication header format"))  if parts.length isnt 2
      return reply(boom.unauthorized(null, "Bearer"))  if parts[0] and parts[0].toLowerCase() isnt "bearer"

      createCallback = (token) ->
        return (err, credentials) ->
          if err
            return reply(err,
              credentials: credentials
              log:
                tags: [
                  "auth"
                  "bearer-auth"
                ]
                data: err
            )
          if not credentials or (token and (not credentials.token or credentials.token isnt token))
            return reply(boom.unauthorized("Invalid token", "Bearer"),
              credentials: credentials
            )
          reply null,
            credentials: credentials


      internals.validateFunc parts[1], createCallback(parts[1])

  return scheme



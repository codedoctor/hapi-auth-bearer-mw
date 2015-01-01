_ = require 'underscore'
Hoek = require 'hoek'
boom = require 'boom'

internals = {}

module.exports.register = (server, options = {}, cb) ->

  options = Hoek.applyToDefaults {clientId: null,_tenantId:null} , options

  internals.clientId = options.clientId
  internals._tenantId = options._tenantId

  Hoek.assert(internals.clientId, 'Missing required clientId property in hapi-auth-bearer-mw configuration');
  Hoek.assert(internals._tenantId, 'Missing required _tenantId property in hapi-auth-bearer-mw configuration');


  internals.hapiOauthStoreMultiTenant = server.plugins['hapi-oauth-store-multi-tenant']
  Hoek.assert internals.hapiOauthStoreMultiTenant,"Could not access oauth store. Make sure 'hapi-oauth-store-multi-tenant' is loaded as a plugin."

  internals.hapiUserStoreMultiTenant = server.plugins['hapi-user-store-multi-tenant']
  Hoek.assert internals.hapiUserStoreMultiTenant,"Could not access user store. Make sure 'hapi-oauth-store-multi-tenant' is loaded as a plugin."

  internals.oauthAuth = -> internals.hapiOauthStoreMultiTenant?.methods?.oauthAuth
  internals.users = -> internals.hapiUserStoreMultiTenant?.methods?.users

  Hoek.assert _.isFunction internals.oauthAuth, "No oauth auth accessible."
  Hoek.assert _.isFunction internals.users, "No users accessible."

  server.auth.scheme 'hapi-auth-bearer-mw', internals.bearer
  cb()

module.exports.register.attributes =
    pkg: require '../package.json'

internals.validateFunc = (secretOrToken, cb) ->

  internals.oauthAuth().validate secretOrToken,internals.clientId, {}, (err,infoResult) ->
    return cb err if err
    return cb null, null unless infoResult and infoResult.isValid # No token found, not authorized, check

    Hoek.assert infoResult.actor,"No actor present in token result"
    Hoek.assert infoResult.actor.actorId,"No actor id present in token result"

    scopes = ['user-bearer-access']
    scopes.push s for s in infoResult.scopes || []

    credentials = 
      id: infoResult.actor.actorId.toString()
      _id: infoResult.actor.actorId.toString()
      clientId: infoResult.clientId
      isValid: !!infoResult.isValid
      isClientValid: !!infoResult.isClientValid
      isAnonymous: false
      scopes: scopes
      scope: scopes
      expiresIn: infoResult.expiresIn
      token: secretOrToken #Important
      roles: []

    internals.users().get credentials.id,{}, (err,userResult) ->
      console.log "========="
      console.log JSON.stringify(userResult)
      console.log "========="

      return cb err if err

      ###
      If user is not found, we need to return an unauthorized error
      ###
      return cb null,null unless userResult

      userResult = userResult.toObject() if _.isFunction(userResult.toObject)
      userResult._id = userResult._id.toString()

      credentials.name = userResult.username
      credentials.user = userResult
      credentials.roles = userResult.roles if _.isArray(userResult.roles)

      cb null, credentials


internals.bearer = (server, options) ->
  scheme =
    authenticate: (request, reply) ->
      req = request.raw.req
      
      accessToken = request.query['access_token']


      unless accessToken
        authorization = req.headers.authorization
        return reply(boom.unauthorized(null, "Bearer"))  unless authorization
        
        parts = authorization.split(/\s+/)
        return reply(boom.badRequest("Bad HTTP authentication header format"))  if parts.length isnt 2
        return reply(boom.unauthorized(null, "Bearer"))  if parts[0] and parts[0].toLowerCase() isnt "bearer"
        accessToken = parts[1]

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
          reply.continue { credentials: credentials }


      internals.validateFunc accessToken, createCallback(accessToken)

  return scheme



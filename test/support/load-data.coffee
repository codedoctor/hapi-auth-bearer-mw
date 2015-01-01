fixtures = require './fixtures'

module.exports = (server,cb) ->
  hapiUserStoreMultiTenant = server.plugins['hapi-user-store-multi-tenant']
  hapiUserStoreMultiTenant.methods.users.create fixtures.tenantId,fixtures.userA, null,(err,user) ->
    return cb err if err

    hapiOauthStoreMultiTenant = server.plugins['hapi-oauth-store-multi-tenant']

    hapiOauthStoreMultiTenant.methods.oauthApps.create fixtures.tenantId,{name: 'test'}, null, (err,app) ->
      return cb err if err
      hapiOauthStoreMultiTenant.methods.oauthAuth.createOrReuseTokenForUserId fixtures.tenantId,user._id, app.clients[0].clientId, "",['scopeb'], null, (err, token) ->
        return cb err if err
        console.log JSON.stringify(user)
        console.log JSON.stringify(token)

        # create a token now.

        cb null, user, token

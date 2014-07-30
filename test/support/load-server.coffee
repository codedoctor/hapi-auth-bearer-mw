index = require '../../lib/index'
Hapi = require "hapi"
_ = require 'underscore'
hapiIdentityStore = require 'hapi-identity-store'

module.exports = loadServer = (cb) ->
    server = new Hapi.Server 5675,"localhost",{}

    pluginConf = [
        plugin: hapiIdentityStore
      ,
        plugin: index
        options: 
          clientId: "53af466e96ab7635384b71fa"
          accountId: "53af466e96ab7635384b71fb"

    ]

    server.pack.register pluginConf, (err) ->
      cb err,server
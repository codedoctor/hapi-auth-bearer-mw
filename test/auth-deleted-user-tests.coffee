assert = require 'assert'
should = require 'should'
index = require '../lib/index'
_ = require 'underscore'

fixtures = require './support/fixtures'
loadServer = require './support/load-server'
loadDeletedUser = require './support/load-deleted-user'

describe 'WHEN authenticating with a valid user', ->
  server = null
  deletedUser = null
  goodToken = null

  describe 'WITH server setup', ->
    beforeEach (cb) ->
      loadServer (err,serverResult) ->
        return cb err if err
        server = serverResult

        loadDeletedUser server, (err,deletedUserResult,goodTokenResult) ->
          return cb err if err
          deletedUser = deletedUserResult
          goodToken = goodTokenResult
          cb null

    describe 'authenticating with a user', ->
      it 'should create a user if it does not exist', (cb) ->
        options =
          method: "POST"
          url: "/test"
          headers: 
            "Authorization" : "Bearer " + goodToken.accessToken.toString()

        server.inject options, (response) ->
          response.statusCode.should.equal 401

          should.exist response.headers
          response.headers.should.have.property 'www-authenticate','Bearer error="Invalid token"'

          should.exist response.result
          response.result.should.have.property 'error','Unauthorized'
          response.result.should.have.property 'message','Invalid token'

        
          cb null


    

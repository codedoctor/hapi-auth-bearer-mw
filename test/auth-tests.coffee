assert = require 'assert'
should = require 'should'
index = require '../lib/index'
_ = require 'underscore'

fixtures = require './support/fixtures'
loadServer = require './support/load-server'
loadData = require './support/load-data'

describe 'WHEN authenticating with a valid user', ->
  server = null
  goodUser = null
  goodToken = null

  describe 'WITH server setup', ->
    beforeEach (cb) ->
      loadServer (err,serverResult) ->
        return cb err if err
        server = serverResult

        loadData server, (err,goodUserResult,goodTokenResult) ->
          return cb err if err
          goodUser = goodUserResult
          goodToken = goodTokenResult
          cb null

    describe 'authenticating with a user', ->
      it 'should create a user if it does not exist', (cb) ->
        options =
          method: "POST"
          url: "/test"
          headers: 
            "Authorization" : "Bearer " + goodToken.accessToken.toString()

        console.log "INJECTING TOKEN: #{goodToken.accessToken.toString()}"
        server.inject options, (response) ->
          response.statusCode.should.equal 200    
          should.exist response.result

          r = response.result
          r.should.have.property( "id").be.a.String.lengthOf(24)
          r.should.have.property("clientId").be.a.String
          r.should.have.property("isValid", true).be.a.Boolean
          r.should.have.property("isAnonymous", false).be.a.Boolean
          r.should.have.property "name", fixtures.username
          r.should.have.property("isClientValid", true).be.a.Boolean

          r.should.have.property("scope").be.an.Array.lengthOf(1) # Depreciated
          r.should.have.property("scopes").be.an.Array.lengthOf(1)
          should.exist r.scopes[0]
          r.scopes[0].should.be.a.String.equal('user-bearer-access')

          r.should.have.property("roles").be.an.Array.lengthOf(3)
          should.exist r.roles[0]
          r.roles[0].should.be.a.String.equal('rolea')
          should.exist r.roles[1]
          r.roles[1].should.be.a.String.equal('roleb')
          should.exist r.roles[2]
          r.roles[2].should.be.a.String.equal('rolec')

          r.should.have.property("user").be.an.Object
          r.user.should.have.property("_id").be.a.String

          #console.log JSON.stringify(response.result,null, 2)

          cb null


    describe 'authenticating without a user', ->
      it 'should not be authenticated', (cb) ->
        options =
          method: "POST"
          url: "/test"

        server.inject options, (response) ->
          response.statusCode.should.equal 401

          should.exist response.headers
          response.headers.should.have.property 'www-authenticate','Bearer'

          should.exist response.result
          response.result.should.have.property 'error','Unauthorized'
          response.result.should.have.property 'message','Missing authentication'

        
          cb null


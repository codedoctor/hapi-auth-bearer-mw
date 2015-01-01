(function() {
  var Hoek, boom, internals, _;

  _ = require('underscore');

  Hoek = require('hoek');

  boom = require('boom');

  internals = {};

  module.exports.register = function(plugin, options, cb) {
    if (options == null) {
      options = {};
    }
    options = Hoek.applyToDefaults({
      clientId: null,
      _tenantId: null
    }, options);
    internals.clientId = options.clientId;
    internals._tenantId = options._tenantId;
    Hoek.assert(internals.clientId, 'Missing required clientId property in hapi-auth-bearer-mw configuration');
    Hoek.assert(internals._tenantId, 'Missing required _tenantId property in hapi-auth-bearer-mw configuration');
    internals.hapiOauthStoreMultiTenant = plugin.plugins['hapi-oauth-store-multi-tenant'];
    Hoek.assert(internals.hapiOauthStoreMultiTenant, "Could not access oauth store. Make sure 'hapi-oauth-store-multi-tenant' is loaded as a plugin.");
    internals.hapiUserStoreMultiTenant = plugin.plugins['hapi-user-store-multi-tenant'];
    Hoek.assert(internals.hapiUserStoreMultiTenant, "Could not access user store. Make sure 'hapi-oauth-store-multi-tenant' is loaded as a plugin.");
    internals.oauthAuth = function() {
      var _ref, _ref1;
      return (_ref = internals.hapiOauthStoreMultiTenant) != null ? (_ref1 = _ref.methods) != null ? _ref1.oauthAuth : void 0 : void 0;
    };
    internals.users = function() {
      var _ref, _ref1;
      return (_ref = internals.hapiUserStoreMultiTenant) != null ? (_ref1 = _ref.methods) != null ? _ref1.users : void 0 : void 0;
    };
    Hoek.assert(_.isFunction(internals.oauthAuth, "No oauth auth accessible."));
    Hoek.assert(_.isFunction(internals.users, "No users accessible."));
    plugin.auth.scheme('hapi-auth-bearer-mw', internals.bearer);
    return cb();
  };

  module.exports.register.attributes = {
    pkg: require('../package.json')
  };

  internals.validateFunc = function(secretOrToken, cb) {
    return internals.oauthAuth().validate(secretOrToken, internals.clientId, {}, function(err, infoResult) {
      var credentials, s, scopes, _i, _len, _ref;
      if (err) {
        return cb(err);
      }
      if (!(infoResult && infoResult.isValid)) {
        return cb(null, null);
      }
      Hoek.assert(infoResult.actor, "No actor present in token result");
      Hoek.assert(infoResult.actor.actorId, "No actor id present in token result");
      scopes = ['user-bearer-access'];
      _ref = infoResult.scopes || [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        s = _ref[_i];
        scopes.push(s);
      }
      credentials = {
        id: infoResult.actor.actorId.toString(),
        _id: infoResult.actor.actorId.toString(),
        clientId: infoResult.clientId,
        isValid: !!infoResult.isValid,
        isClientValid: !!infoResult.isClientValid,
        isAnonymous: false,
        scopes: scopes,
        scope: scopes,
        expiresIn: infoResult.expiresIn,
        token: secretOrToken,
        roles: []
      };
      return internals.users().get(credentials.id, {}, function(err, userResult) {
        if (err) {
          return cb(err);
        }

        /*
        If user is not found, we need to return an unauthorized error
         */
        if (!userResult) {
          return cb(null, null);
        }
        if (_.isFunction(userResult.toObject)) {
          userResult = userResult.toObject();
        }
        userResult._id = userResult._id.toString();
        credentials.name = userResult.username;
        credentials.user = userResult;
        if (_.isArray(userResult.roles)) {
          credentials.roles = userResult.roles;
        }
        return cb(null, credentials);
      });
    });
  };

  internals.bearer = function(server, options) {
    var scheme;
    scheme = {
      authenticate: function(request, reply) {
        var accessToken, authorization, createCallback, parts, req;
        req = request.raw.req;
        accessToken = request.query['access_token'];
        if (!accessToken) {
          authorization = req.headers.authorization;
          if (!authorization) {
            return reply(boom.unauthorized(null, "Bearer"));
          }
          parts = authorization.split(/\s+/);
          if (parts.length !== 2) {
            return reply(boom.badRequest("Bad HTTP authentication header format"));
          }
          if (parts[0] && parts[0].toLowerCase() !== "bearer") {
            return reply(boom.unauthorized(null, "Bearer"));
          }
          accessToken = parts[1];
        }
        createCallback = function(token) {
          return function(err, credentials) {
            if (err) {
              return reply(err, {
                credentials: credentials,
                log: {
                  tags: ["auth", "bearer-auth"],
                  data: err
                }
              });
            }
            if (!credentials || (token && (!credentials.token || credentials.token !== token))) {
              return reply(boom.unauthorized("Invalid token", "Bearer"), {
                credentials: credentials
              });
            }
            return reply(null, {
              credentials: credentials
            });
          };
        };
        return internals.validateFunc(accessToken, createCallback(accessToken));
      }
    };
    return scheme;
  };

}).call(this);

//# sourceMappingURL=index.js.map

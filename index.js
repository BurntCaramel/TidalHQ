(function() {
  var TidalHQ, path;

  require('coffee-script/register');

  path = require('path');

  TidalHQ = (function() {
    function TidalHQ() {}

    TidalHQ.requireClass = function(className) {
      return require(path.join(__dirname, 'lib', className));
    };

    TidalHQ.prototype.ChannelVideoCheckerApp = TidalHQ.requireClass('ChannelVideoCheckerApp');

    TidalHQ.prototype.ChannelVideoChecker = TidalHQ.requireClass('ChannelVideoChecker');

    TidalHQ.prototype.ChannelVideoRetriever = TidalHQ.requireClass('ChannelVideoRetriever');

    return TidalHQ;

  })();

  module.exports = new TidalHQ;

}).call(this);

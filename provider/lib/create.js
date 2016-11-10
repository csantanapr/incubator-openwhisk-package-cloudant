module.exports = function(tid, logger, utils) {

  // Test Endpoint
  this.endPoint = '/cloudanttriggers/:id';

  // Create Logic
  this.create = function (req, res) {

    var method = 'PUT /cloudanttriggers';

    logger.info(tid, method);
    var args = typeof req.body === 'object' ? req.body : JSON.parse(req.body);

    // validate parameters here

    // if the trigger creation request has not set the max trigger fire limit
    // we will set it here (default value can be updated in ./constants.js)
    if (!args.maxTriggers) {
    	utils.logger.info(tid, method, 'maximum trigger fires has not been set by requester.  setting it to the default value of infinity.');
    	args.maxTriggers = utils.defaultTriggerFireLimit;
    }

    // validate the callback action and name
    if (!args.callback || !args.callback.action || !args.callback.action.name) {
        // TODO: update error code to indicate that content provided is not correct
        utils.logger.warn(tid, method, 'Your callback is unknown for cloudant trigger:', args.callback);
        res.status(400).json({
            error: 'You callback is unknown for cloudant trigger.'
        });
        return;
    }

    // validate id
    var id = req.params.id;
    if (!id) {
        // TODO: update error code to indicate that content provided is not correct
        utils.logger.warn(tid, method, 'Your trigger ID has not been set', id);
        res.status(400).json({
            error: 'Your trigger ID has not been set.'
        });
        return;
    }

    var trigger = utils.initTrigger(args, id);

    var promise = utils.createTrigger(trigger, utils.retryCount);
    promise.then(function(newTrigger) {
        utils.logger.info(tid, method, "Trigger was added and database is confirmed.", newTrigger);
        utils.addTriggerToDB(newTrigger, res);
    }, function(err) {
        utils.logger.error(tid, method, "Trigger could not be created.", err);
        utils.deleteTrigger(id);
        res.status(400).json({
            message: "Trigger could not be created.",
            error: err
        });
    });

  };

};

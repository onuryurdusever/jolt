var Action = function() {};

Action.prototype = {
    
    run: function(arguments) {
        // Pass the URL directly without JavaScript preprocessing
        arguments.completionFunction({
            "URL": document.URL,
            "title": document.title
        });
    },
    
    finalize: function(arguments) {
        // No finalization needed
    }
    
};

var ExtensionPreprocessingJS = new Action;

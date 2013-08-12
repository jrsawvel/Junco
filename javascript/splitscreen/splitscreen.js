var MINI = require('minified'); 
var $ = MINI.$, $$ = MINI.$$, EE = MINI.EE;


$(function() {
    $('#moveButton').on('click', function() {
        $('#text_preview').animate({$$fade: 0}, 500); // fade out
// 6aug2013        $('#col_left').set({$left: '19%'} );
// 6aug2013        $('.col').set({$width: '60%'} );
        $('#col_left').set('$', '+singlecol -col');
    });

    $('#resetButton').on('click', function() {
// 6aug2013        $('#col_left').set({$left: '1%'} );
        $('#text_preview').animate({$$fade: 1}, 500); // fade in 
// 6aug2013        $('.col').set({$width: '48%'} );
        $('#col_left').set('$', '+col -singlecol');
    });

    $('#previewButton').on('click', function() {
// 6aug2013        $('#col_left').set({$left: '1%'} );
        $('#text_preview').animate({$$fade: 1}, 500); // fade in 
// 6aug2013        $('.col').set({$width: '48%'} );
        $('#col_left').set('$', '+col -singlecol');

//        $('#saveButton').set('$', '+greenbutton -bluebutton');

        var markup = $$('#tx_input').value;
        markup=escape(markup);
        $.request('post', 'http://jothut.com/cgi-bin/dvlpjunco.pl/addarticle', {article: markup, sb: 'Preview', formtype: 'ajax'})
            .then(function(response) {
                 $('#text_preview').set('innerHTML', response);
             })
            .error(function(status, statusText, responseText) {
                $('#text_preview').fill('response could not be completed.');
            });
    });

    $('#saveButton').on('click', function() {
        $('#text_preview').animate({$$fade: 1}, 500); // fade in 
// 6aug2013        $('#col_left').set({$left: '1%'} );
// 6aug2013        $('.col').set({$width: '48%'} );
        $('#col_left').set('$', '+col -singlecol');

        var markup = $$('#tx_input').value;
        markup=escape(markup);
        $.request('post', 'http://jothut.com/cgi-bin/dvlpjunco.pl/addarticle', {article: markup, sb: 'Save', formtype: 'ajax'})
            .then(function(response) {
                 $('#text_preview').set('innerHTML', response);
                 var regex = /^Error: /;
                 if ( regex.test(response) ) {
                 } else {
                     $('#saveposttext').set({$color: '#fff'});
                     setTimeout(function() {$('#saveposttext').set({$color: '#120a8f'})}, 2000);
                 }
             })
            .error(function(status, statusText, responseText) {
                $('#text_preview').fill('response could not be completed.');
            });
    });
});


var MINI = require('minified'); 
var $ = MINI.$, $$ = MINI.$$, EE = MINI.EE;

var keyCounter=0;
var autoSaveInterval=300000   // in milliseconds. default = 5 minutes.
var intervalID=0;
var prevLength=0;
var currLength=0;
var isFocus=0;

function countKeyStrokes () {
    keyCounter++;    
}
    
$(function() {

/*
Mousetrap.bindGlobal('ctrl+shift+p', function() {
     alert("preview");
    previewPost();
});
*/
// Mousetrap.bindGlobal('ctrl+shift+p', previewPost );

    onkeydown = function(e){
        if(e.ctrlKey && e.keyCode == 'P'.charCodeAt(0)){
        //  if(e.ctrlKey && e.shiftKey && e.keyCode == 'P'.charCodeAt(0)){
            e.preventDefault();
            previewPost();
        }

        if(e.ctrlKey && e.keyCode == 'S'.charCodeAt(0)){
            e.preventDefault();
            keyCounter++; // force a save even if no editing occurred since user clicked the save link.
            savePost();
        }

        if(e.ctrlKey && e.keyCode == 'U'.charCodeAt(0)){
            e.preventDefault();
            singleScreenMode();
        }

        // bare minimum view. large textarea box only. no border. no nav bar. no other links. no buttons.
        if(e.ctrlKey && e.keyCode == 'J'.charCodeAt(0)){
            e.preventDefault();
            $('body').set({$background: '#fff'} );
            $('#navmenu').set({$display: 'none'} );
            $('#tx_input').set({$background: '#fff'} );
            $('#tx_input').set({$border: 'none'} );
            $('#tx_input').set({$color: '#222'} );
            $('#col_left').set({$padding: '1em 0 0 0'} );
            singleScreenMode();
        }

        // display a 5-line text area box
        if(e.ctrlKey && e.keyCode == 'H'.charCodeAt(0)){
            e.preventDefault();
            $('body').set({$background: '#fff'} );
            $('#navmenu').set({$display: 'none'} );
            $('#tx_input').set({$background: '#fff'} );
            $('#tx_input').set({$border: 'none'} );
            $('#tx_input').set({$color: '#222'} );
            $('#tx_input').set({$height: '150px'} );
            $('#tx_input').set({$margin: '30% 0 0 0'} );
            $('#col_left').set({$padding: '1em 0 0 0'} );
            isFocus=1;
            singleScreenMode();
        }

        if(e.ctrlKey && e.keyCode == 'B'.charCodeAt(0)){
            e.preventDefault();
            $('body').set({$background: '#ddd'} );
            $('#navmenu').set({$display: 'inline'} );
            $('#tx_input').set({$background: '#f8f8ff'} );
            $('#tx_input').set({$border: '1px solid #bbb'} );
            $('#tx_input').set({$color: '#222'} );
            $('#col_left').set({$padding: '0'} );
            if ( isFocus ) {            
                $('#tx_input').set({$margin: '0 0 0 0'} );
                $('#tx_input').set({$height: '100%'} );
                ifFocus=0;
            }
            splitScreenMode();
        }

        if(e.ctrlKey && e.keyCode == 'D'.charCodeAt(0)){
            e.preventDefault();
            $('body').set({$background: '#181818'} );
            $('#tx_input').set({$background: '#181818'} );
            $('#tx_input').set({$color: '#c0c0c0'} );
        }
    }

    // autosave every five minutes
//    setInterval(function(){savePost()},300000); 
    intervalID = setInterval(function(){savePost()},autoSaveInterval); 


// ******************** 
// SINGLE-SCREEN MODE
// ******************** 

    $('#moveButton').on('click', singleScreenMode);

    function singleScreenMode () {
        $('#text_preview').animate({$$fade: 0}, 500); // fade out
        $('#tx_input').animate({$$fade: 1}, 500); // fade in
        $('#col_right').set('$', '+col -prevsinglecol');
        $('#col_left').set('$', '+singlecol -col');
// 25aug2013        $('#col_right').set({$left: '0%'} );
        $('#col_right').set({$float: 'right'} );
        $('#col_right').set({$position: 'relative'} );
// 25aug2013        $('#col_right').set({$left: '90%'} );
        document.getElementById('tx_input').focus();
    }


// ******************** 
// SPLIT-SCREEN MODE
// ******************** 

    $('#resetButton').on('click', splitScreenMode);

    function splitScreenMode () {
        $('#tx_input').animate({$$fade: 1}, 500); // fade in 
        $('#text_preview').animate({$$fade: 1}, 500); // fade in 
        $('#col_left').set('$', '+col -singlecol');
        $('#col_right').set('$', '+col -prevsinglecol');
// 24aug2013        $('#col_right').set({$left: '0%'} );
        $('#col_right').set({$float: 'right'} );
        $('#col_right').set({$position: 'relative'} );
        document.getElementById('tx_input').focus();
    }


// **********
// PREVIEW
// ********** 

    $('#previewButton').on('click', previewPost);

    function previewPost () {
        var col_type = $('#col_left').get('@class');

        var action        = $('#splitscreenaction').get('@value');
        var cgiapp        = $('#splitscreencgiapp').get('@value');
        var postid        = $('#splitscreenpostid').get('@value');
        var postdigest    = $('#splitscreenpostdigest').get('@value');

        if ( col_type === "singlecol" ) { 
            $('#col_left').set('$', '+col -singlecol');
            $('#tx_input').animate({$$fade: 0}, 500); // fade out
            $('#col_right').set('$', '+prevsinglecol -col');
// 25aug2013            $('#col_right').set({$left: '19%'} );
            $('#col_right').set({$float: 'normal'} );
            $('#col_right').set({$position: 'absolute'} );
            $('#text_preview').animate({$$fade: 1}, 500); // fade in 
        } 

        var markup = $$('#tx_input').value;

        var regex = /^autosave=(\d+)$/m;
        var myArray;
        if ( myArray = regex.exec(markup) ) {
            if ( myArray[1] > 0  &&  (myArray[1] * 1000) != autoSaveInterval ) {
                autoSaveInterval = myArray[1] * 1000; 
                clearInterval(intervalID);
                intervalID = setInterval(function(){savePost()},autoSaveInterval); 
            }
        }

        markup=escape(markup);

        var paramstr;

// alert(action);
// alert(cgiapp);
// alert(postid);
// alert(postdigest);

        $.request('post', cgiapp + '/' + action , {markupcontent: markup, sb: 'Preview', formtype: 'ajax', articleid: postid, contentdigest: postdigest})
            .then(function(response) {
                 var obj = $.parseJSON(response);
                 if ( obj['errorcode'] ) {
                     $('#text_preview').set('innerHTML', obj['errorstring']);
                 } else {
                     $('#text_preview').set('innerHTML', obj['content']);
                 }
             })
            .error(function(status, statusText, responseText) {
                $('#text_preview').fill('response could not be completed.');
            });
    }


// **********
// SAVE
// ********** 

    $('#saveButton').on('click', forceSave);

    function forceSave () {
        keyCounter++;
        savePost();
    }

    function savePost () {
        var markup = $$('#tx_input').value;

        currLength = markup.length;

        if ( keyCounter == 0 && currLength == prevLength ) {
            return;
        }
    
        prevLength = currLength; 
        keyCounter=0;
 
        var col_type = $('#col_left').get('@class');

        var action        = $('#splitscreenaction').get('@value');
        var cgiapp        = $('#splitscreencgiapp').get('@value');
        var postid        = $('#splitscreenpostid').get('@value');
        var postdigest    = $('#splitscreenpostdigest').get('@value');


        markup=escape(markup);

//        $.request('post', cgiapp + '/' + action, {markupcontent: markup, sb: 'Save', formtype: 'ajax'})

        var sbtype = "Save";

        if ( action === "updateblog" ) {
            sbtype = "Update";
        }

          $.request('post', cgiapp + '/' + action , {markupcontent: markup, sb: sbtype, formtype: 'ajax', articleid: postid, contentdigest: postdigest})
            .then(function(response) {
                 var obj = $.parseJSON(response);

                 if ( obj['errorcode'] ) {
                     $('#text_preview').animate({$$fade: 1}, 500); // fade in 
                     $('#text_preview').set('innerHTML', obj['errorstring']);
                     $('#col_left').set('$', '+col -singlecol');
                 } else {
                     $('#text_preview').set('innerHTML', obj['content']);
// 14jan2014                     $('#saveposttext').set({$color: '#fff'});
// 14jan2014                     setTimeout(function() {$('#saveposttext').set({$color: '#120a8f'})}, 2000);
                     $('#saveposttext').set({$color: '#000'});
                     setTimeout(function() {$('#saveposttext').set({$color: '#f8f8f8'})}, 2000);
                     $('#splitscreenaction').set('@value', 'updateblog');
                     $('#splitscreenpostid').set('@value', obj['articleid']);
                     $('#splitscreenpostdigest').set('@value', obj['contentdigest']);
                 }
                 // var regex = /^Error: /;
                 // if ( regex.test(response) ) {
             })
            .error(function(status, statusText, responseText) {
                $('#text_preview').fill('response could not be completed.');
            });
    }

});


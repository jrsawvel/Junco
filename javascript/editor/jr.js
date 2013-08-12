var MINI = require('minified'); 
var $ = MINI.$, $$ = MINI.$$, EE = MINI.EE;

$(function() {
    $('#moveButton').on('click', function() {
//        $('#col_left').animate({$left: 25 + '%', $top: 20 + 'px'}, 500);
// 17jul2013        $('#col_left').set({$left: '25%'} );
        $('#col_left').set({$left: '19%'} );
//        $('#col_right').animate({$left: 100 + '%', $top: 0 + 'px'}, 500);
        $('#text_preview').set({$background: '#ddd'} );
        $('#text_preview').set({$color: '#ddd'} );
// 17jul2013 added the width 60% line on 17jul2013. default is 48%
        $('.col').set({$width: '60%'} );
    });

    $('#resetButton').on('click', function() {
//        $('#col_left').animate({$left: '0px', $top: 20 +  'px'}, 500 );
//        $('#col_right').animate({$left: '0px', $top: '0px'}, 500 );
        $('#text_preview').set({$background: '#fff'} );
        $('#text_preview').set({$color: '#000'} );
        $('#col_left').set({$left: '1%'} );
        $('.col').set({$width: '48%'} );
    });
});


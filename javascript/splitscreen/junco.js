jQuery(function($){
    var tally = $('body > h1').outerHeight();
    col.children().each(function(){ tally += $(this).outerHeight(); });
    var space = col.height() - ( tally - md.outerHeight() );
    $('#tx_input, #text_preview, #html_output, #syntax_guide').height( space - 4 );
});

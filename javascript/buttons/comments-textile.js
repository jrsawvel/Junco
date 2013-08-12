// from http://placenamehere.com/photographica/js_textareas.html
// previous version used http://www.massless.org/mozedit/
// first version used megnut/blogger's code

function pnhTextareaInsert(taID, text1, text2) {
	// grab the textarea off the dom tree
	var ta = document.getElementById(taID);
		
	if (document.selection) { //IE win
		// code ripped/modified from Meg Hourihan 
		// http://www.oreillynet.com/pub/a/javascript/2001/12/21/js_toolbar.html
		var str = document.selection.createRange().text;
		ta.focus();
		var sel = document.selection.createRange();
		sel.text = text1 + str + text2;
	
	} else if (ta.selectionStart | ta.selectionStart == 0) { // Mozzzzzzila relies on builds post bug #88049
		// work around Mozilla Bug #190382
		if (ta.selectionEnd > ta.value.length) { ta.selectionEnd = ta.value.length; }

		// decide where to add it and then add it
		var firstPos = ta.selectionStart;
		var secondPos = ta.selectionEnd+text1.length; // cause we're inserting one at a time

		ta.value=ta.value.slice(0,firstPos)+text1+ta.value.slice(firstPos);
		ta.value=ta.value.slice(0,secondPos)+text2+ta.value.slice(secondPos);
		
		// reset selection & focus... after the first tag and before the second 
		ta.selectionStart = firstPos+text1.length;
		ta.selectionEnd = secondPos;
		ta.focus();
	}	
}

function pnhEditTextarea(textarea_id, action) {

	// decide what you're addding
	var startTag = "";
	var endTag = "";
	
	switch (action) {
		case "pound":	
			startTag = "#";
			endTag = "";
			break;
		case "hyphen":	
			startTag = "-";
			endTag = "";
			break;
		case "period":	
			startTag = ".";
			endTag = "";
			break;
		case "strong":	
			startTag = "*";
			endTag = "*";
			break;
		case "emphasis":	
			startTag = "_";
			endTag = "_";
			break;
		case "a_href":
			var userInput = prompt("Please enter the site you'd like to link", "http://");
                        if ( userInput != null ) {
   			    // startTag = "<a href=\""+userInput+"\">";
			    // endTag = "<\/a>";
   			     startTag = "\"";
			     endTag = "\":" + userInput;
                        } 
			break;
		}

	pnhTextareaInsert(textarea_id,startTag,endTag);

	return false;
}

	/* chris w of massless keystroke script */ 
	
	document.onkeypress = function (e) {
	  if (document.all) {
		key=event.keyCode; 
		if (key == 1) pnhEditTextarea("comment", "a_href");
		if (key == 2) pnhEditTextarea("comment", "strong");
		if (key == 20) pnhEditTextarea("comment", "emphasis");
	  }
	  else if (document.getElementById) {
	  	ctrl=e.ctrlKey; shft=e.shiftKey; chr=e.charCode;
	  	if (ctrl) if (shft) if (chr==65) pnhEditTextarea("comment", "a_href");
	  	if (ctrl) if (shft) if (chr==66) pnhEditTextarea("comment", "strong");
	  	if (ctrl) if (shft) if (chr==84) pnhEditTextarea("comment", "emphasis");
	  }
	  return true;
	} 
	/* end chris w. script */


	/*
	written by meg hourihan
	http://www.megnut.com
	meg@megnut.com
	
	warning: it only works for IE4+/Win and Moz1.1+
	feel free to take it for your site
	but leave this text in place.
	any problems, let meg know.
	*/
	
	function mouseover(el) {
		el.className = "raise";
		}
	
	function mouseout(el) {
		el.className = "buttons";
	}
	
	function mousedown(el) {
		el.className = "press";
	}
	
	function mouseup(el) {
		el.className = "raise";
	}
	/* end meg script */
	
	
	

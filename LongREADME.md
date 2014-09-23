# Junco User Documentation

Junco was designed to support multiple users who create blog posts, microblog posts, replies, and follow users and tags. But Junco can be used as a personal publishing site too.

Example usage:

* personal site - <http://jothut.com>
* multi-user test version - [http://junco.soupmode.com](http://junco.soupmode.com)


## Account Creation

On the sign-up page, enter a username and a valid email address. The system will email an auto-generated password and a link to activate the account. After the account is activated, the user can login.

For the test, multi-user version mentioned above, no email is sent, so a valid email address is not required, but the e-mail syntax still needs to be correct. For this test site, the password and the link to activate the account are displayed on the screen. 


## Logging In

To log into the app, enter the email address and password. The username is not used for logging in. The username is used for display within the app. Posts are assigned to the username.



## Changing Password and Email

After logging in, you can click on your username and follow the link and form fields to change the password and email address.

Requirements for passwords created by the user:

* it must be least 8 characters long
* the maximum length is 30 characters
* it must contain at least 4 alpha characters
* it must contain at least 2 numeric characters
* it must contain at least 2 characters from the following list: !@$%^&*
* the alphas, digits, and jibberish characters do not have to be unique, so a password can contain two exclamation marks, which satisfies the jibberish requirement.


## Generate New Password

On the login page, you can request the app to generate a new password for the username and email address provided. The new password will be sent to the email address. For the test site (debug mode), the new password is displayed on the screen.


## Editing the Profile Page

You can personalize your profile page by adding links, plain text, embedded photos and videos, or Textile markup to create HTML. The profile page data entry box supports template includes and the double-bracket wiki link feature.


## Search

The search applies to microblog posts, blog posts, replies, webmentions, all the content created, except blog posts that have the private=yes command applied.

In the text input field box for searching, enter one of the following:

* the search term(s)
* the search terms separated by AND
* the terms separated by OR

The AND-OR operators need to be typed in uppercase.

On a search results page, a permalink for the search is displayed with a pound sign link, and an RSS link also exists for the search results. The RSS feed contains the 20 most recently created/updated blog and microblog posts.

This simple search may need enhanced because it will return results that contain part of the search term. For example, a search on the word "junco" will also return results that contain the phrase "juncocode".

Default search is done on the exact phrase of words typed into the search text field box.

Separate words with OR to match on any word, which means the search is a match if at least one word in the list is found in the post.

Use AND to match on all words, which means all of the words must appear somewhere within the post.

Your search terms can be in upper or lower case, but the OR and AND must be in caps.

Example search inputs:

* exact phrase: Lake Erie
* match any word: Toledo OR Monroe OR Bowling Green
* match all words: swamp AND river AND lake

Currently, the AND and OR commands cannot be combined.

You can also use the URL to conduct a search.

Example:

 /search/art

The AND and OR commands be used in the URL too by connecting words with the plus sign:

  /search/toledo+AND+monroe



## Hashtags

Microblog posts (notes) and blog posts (articles) are limited to a max of eight hashtags.

Hashtag format consists of meaningful, categorical, alphanumeric text preceded by the pound sign. 

Hashtags are used to organize and identify content. Tags help with searching.

I like to start with the general and move to the specific when including tags.

Examples (with the pound signs excluded):

* nature - insects - butterflies
* sports - football - nfl - browns
* media - design - mobile - app

A "tags" link exists to show all microblog and blog postings with tags. The tags can be displayed by name, count, tag cloud, and the top 30 tags.

An RSS feed can be obtained for each tag. The feed shows the 20 most recently created/updated posts.

Displaying posts that contain a particular hashtag is really a special form of the search function.

The AND-OR operators can be used with searching or displaying a stream of tagged posts.

Example URL:

* <http://jothut.com/cgi-bin/junco.pl/tag/mobile+AND+design/>

The above URL will return all postings (microblog and blog) that contain the hashtags "mobile" and "design."


## Microblog Posts or Notes

These are short posts with a limit of 300 characters. They are entered in the small textarea box, located on the homepage.

Microblog posts do not contain titles.

No preview, just a post button.

The only formatting includes:

* Raw URLs are converted into clickable links.
* Hashtags converted into clickable search links.
* ``/1234/`` means linking to another microblog post that has ID number 1234.

Microblog posts cannot be edited.

But microblog posts can be deleted from the home page stream by clicking the `[delete]` link. The post is not removed from the stream. A deleted post can only be viewed on the home page stream by the logged-in owner. The deleted post will appear with very small text with a light yellow background. The deleted post can be added to public viewing by clicking the `[undelete]` link.

The RSS feed for your microblog posts can be accessed on your profile page.


## Blog Posts or Articles

These can be short or very long.

Posts can be entered in a medium-sized textarea box, or the enhanced 'editor' can be used.

Blog posts can be previewed before being saved.

Blog posts can be edited.


### Versions

Old versions are preserved. To revert back to an old version, edit the old post and save the post.


### Differences

Differences can be run on two versions, showing changes, additions, and deletions.


### Titles

No separate input text field exists for the title. The first line in the blog post is used as the title. If the line is long, then the first 150 characters will be the title.

If the title contains a colon punctuation mark, then the text preceding the punctuation mark must equal your username. This namespace convention allows you to create common titles with your in the title.

If you create a blog post that uses a title that matches an existing, created by you or someone else, then an error will be displayed about the title already being used.


### Markup Support

Blog posts support Textile, Markdown, and MultiMarkdown formatting. Textile is the default markup.

Many HTML tags are also supported.


### Blog Post Types

Blog posts can be set to private where only you can view them when you are logged-in. Private posts will not appear within your home page stream. You can access your private posts through your profile page.

Blog posts can be set to draft where they are still publicly displayed, but draft posts do not appear on your home page stream. Draft posts could be found through searching. You can view your draft posts through your profile page. Also, draft posts will be automatically created when the double-bracket wiki markup is used, and the post identified by the title contained within the double brackets does not exit. 


### Table of Contents

If header lines are used within a blog post, such as h1, h2, h3, etc.,  then by default a table of contents is created and displayed at the upper right area of the web page. The table of contents  display, however, can be disabled with the ``toc`` command.

When the browser is re-sized smaller or when viewing the blog post on small screens, the table of contents is not displayed.


### Viewing Blog Source

Users can view the markup source for a blog post.


### Related Articles

(Blog posts)

Based upon the hashtags used within a blog post, a list of "Related articles" is displayed at the bottom of the blog post. This list is generated when two or more hashtags match other blog posts. Five related articles are displayed. If more than five exist, a "more" link is displayed that will take you to the page that shows all the related articles. This feature does not apply to microblog/notes postings.


### Blog Posts Stream

When showing a stream that includes blog postings, only the first 250 characters of each blog post is displayed within the stream. If the post is longer than 250 characters, a "more" link is displayed.

Blog posts can be deleted from the home page stream by clicking the `[delete]` link. The post is not removed from the stream. When you are logged-in, you can view a deleted post on your home page stream. The deleted post will appear with very small text with a light yellow background. The deleted post can be added to public viewing by clicking the `[undelete]` link.

The stream is displayed by recently updated date, which could be creation date for a new post or modified date for an old post.


### RSS

The RSS stream for your blog posts can be accessed on your profile page. The feed contains the 20 most recently created/updated blog postings (articles).


### Archives

The "archives" page only applies to blog posts. The archives page shows a list of months for each year that posts exist. Clicking a link will display a stream of blog posts that were created in that month for that year.


### Special Blog Formatting Tag

The ``blog_[username]`` hashtag is used to create a specially formatted stream of blog postings. Only the author's username can follow the ``blog_`` text when using this hashtag. After clicking on this special tag, the formatted stream will look more like a traditional blog home page. 

It's recommended to use the ``more.`` command when applying the ``blog_`` hashtag. The text preceding the ``more.`` command will appear on the specially formatted blog home page stream. On the blog home page, the "more" link will be displayed to indicate more text exist. 

If the ``blog_`` tag is applied to a post, and the ``more.`` command is not used, then the entire blog post will be displayed on the specially formatted blog home page stream, which may be desired for small posts.

The home page stream for this special tag displays posts by creation date. Recently updated blog posts do not appear at the top of the stream, which is what happens on the normal stream display for blog/article postings.

This special tag also includes an RSS feed that displays the 20 most recently created blog postings. Again, recently updated blog posts do not appear at the top of the RSS feed.

The special ``blog_`` tag attempts to preserve traditional blog display functionality.


#### Image Headers

These commands apply to individual blog posts that use the special ``blog_`` tag.

 imageheader=URL to image

or 

 largeimageheader=URL to image

The large image is displayed at the top of the page when viewing the blog post.

These large images, however, are not displayed when viewing the stream of specially formatted blog posts.


### Redirecting

To redirect a user to another blog post, use:

@blog_post_id

Example: @123 

The at-sign needs to appear at the beginning of the line of the blog post you don't  want displayed. The blog post id follows the at-sign. The user will be shown the blog post represented by the id number following the at-sign.

Another user will see text at the top of the page indicating the user was redirected from another page. If you own the post, then you can edit the page with the redirect code.

The blog post containing the redirect command can still contain other content in case it's a temporary redirect. 


### Power Commands

These commands typically start at the beginning of a new line. Most take either a "yes" or "no" option.

* toc=yes|no
* draft=yes|no
* replies=yes|no
* private=yes|no
* showintro=yes|no
* code=yes|no
* markdown=yes|no
* multimarkdown=yes|no
* webmention=yes|no
* imageheader=URL
* largeimageheader=URL
* calc=arithmetic expression


### Embedding Media

The img HTML tag is permitted.

Markdown and Textile provide commands to display an image.

These custom commands are used to display other media: 

* gmap=
* kickstarter=
* facebook=
* youtube=
* vimeo=
* gist=
* insta=http://instagram.com/p/tOvJxJtQhC - will display image size as 320x320 pixels
* or specify a size with insta=http://instagram.com/p/tOvJxJtQhC 480x480


A part of the URL that points to the video, map, or code snippet is placed after the appropriate command.


### Enhanced Blog Writing Area

This "editor" was created with JavaScript.

You can type and view in split-screen or single-screen modes.

Auto-save occurs every five minutes, provided that at least one key was pressed. This applies to adding, deleting, or rearranging text. The "save" link can be clicked to save too.

If the "preview" link is clicked while in split-screen mode, then the preview will be displayed in the right pane.

If the "preview" link is clicked while typing in single-screen mode, then the preview will be displayed in single-screen mode. This preview will display at the same width as the website's width defined in the CSS file.

Clicking the right arrows changes the mode to single-screen. Clicking the left arrows switches to split-screen mode.

This does not contain live preview. When testing, I found live preview to be too distracting. As I typed, I could see letters flashing in the preview pane out of the corner of my eye. Plus, I have added too many custom formatting options, such as custom Textile-like formatting commands, template includes, wiki bracket links, etc., that are best achieved with a round-trip to the server. Since this round-trip is plenty fast, I don't see this as a problem.


#### Keyboard Commands

When typing in the enhanced view:

* ctrl+P = preview
* ctrl+U = single-screen mode
* ctrl+S = save


#### Old screen shots

br. split screen, typing on left and preview on right.

![enhanced view 1](http://farm6.staticflickr.com/5498/9717594241_f3a6c2cf1c_z.jpg)


br. single screen view for typing.

![enhanced view 2](http://farm4.staticflickr.com/3808/9720824518_26e9d0b76c_z.jpg)


br. single screen view for previewing.

![enhanced view 3](http://farm4.staticflickr.com/3703/9720824284_332b02fddb_z.jpg)

When moving away from the enhanced writing area, you will get a pop-up message, asking if you want to leave the page. Click "confirm" or whatever the answer is to leave the page.

This confirmation pop-up will appear even after you have saved the content.

This confirmation exists because over the years, I've experienced times where I accidentally moved away from a page that I was adding content to, and when I quickly moved back, all my content was gone and not saved. So I added this pop-up as a safety feature.

This "confirm" pop-up, however, does not function on Apple devices. 


### Simpler Enhanced Writing Area

It's also possible to simplify the enhanced writing area even more. These views borrow from the look of the writing area at Github. All buttons or links are removed from the screen display.

These actions only exist as keyboard commands. When writing in this simpler, enhanced view, the above keyboard commands can be used too. And the other actions, such as autosave also works here. It's the same JavaScript editor app, just displayed differently. 

Additional keyboard commands used within the simpler enhanced writing area.

* ctrl+J - bare display that shows only the single text box for writing. no border, no nav bar, no buttons, no links.
* ctrl+H - bare display per above except text box is only five lines tall.
* ctrl+D - change display from dark text on a light background to light text on a dark background.
* ctrl+B - reverts back to the original splitscreen display with original colors, buttons, etc.


## RSS Feeds

RSS feeds are available for the following streams of content:

* blog posts
* special blog_[username] hashtag
* microblog posts
* all postings combined
* search results
* hashtags


## Feed command

You can display results from an RSS or atom feed within a blog post by using the double-curly brace feed command.

{{feed= URL followed by two right curly braces } }

(no space between the two right curly braces.)

The embedded feed will display only the titles. To display description text, use the "desc" attribute after the URL and before the right curly braces.

{{feed=http://someurltorss/file.rss desc } }

(again, no space between the right two curly braces.)

If the feed cannot be retrieved, then the following message is embedded within the blog post:

"Could not retrieve feed for http://someurltorss/file.rss"

Since all content is stored in a database, content is dynamically created on the server and sent to the user. The feed content is included at the time the page is being created on the server.


## Follow Users

To follow the postings by other users, click on the user's username to visit the user's profile page. Then click the green follow button.

You can view the stream of posts for these users.

On your profile page, you can view the list of users that you are following. When viewing your list of followed users, you can click the 'X' to remove or unfollow those users.

You can also unfollow a user by going to the user's profile page and clicking the unfollow button. 


## Follow Tags

To follow the postings tagged by a particular hashtag, click on the hashtag to display its stream of posts, and then click the green follow button.

On your profile page, you can view the list of tags that you are following. When viewing your list of followed tags, you can click the 'X' to remove or unfollow those tags.

And you can also unfollow a tag by clicking the tag to display its stream of posts and then clicking the unfollow button. 


## Backlinks

If you create a blog post that contains a normal URL link or a wiki, double-bracket case link to another blog post within the Junco app, then this other blog post will contain a ``backlinks`` link at the bottom of the post. 

Clicking the ``backlinks`` link will show a page that contains all the blog posts that link to the blog post that you were viewing.


## Generic post display

This will work for displaying either a microblog or blog post.

Instead of the URL containing "microblog" or "blog," the word "post" can be used instead.


## Last Blog Viewed

Your user information in the database is updated to store the last blog post that you viewed.

Your last viewed blog post is the first thing that you see after restarting your browser with the saved-login cookie set or when logging back into the site.


## Text size

To change the site's font size, click on the ``A`` links at the bottom of the site.

A cookie will be set to preserve your font size, but it applies for the device that you are currently using.

Your font size information is not stored in the database.


## Themes

Initially, a dark background with light links theme existed, but at the moment, it's not available. The only theme used is the default view.


### Template Includes

A template blog post can be included into another blog post by surrounding the title of the template post with two curly braces.

{ {Existing Template Blog Title} }

(except no space between the two right curly braces)

The HTML of the template post will be included into the post using the above command at the time the blog post is displayed to the user. That way changes made to the template will be seen immediately the next time the post with the include is displayed to the user.

Example:

You can include the contents in post Underconstruction into another post by typing { {Underconstruction} } (minus the space between the curly braces) into the other post.

The above example produces:

{{Underconstruction}}

Better explanation:

* blog post A is titled "This is Test A"
* blog post B wants to include content from blog post A by using: {{This is Test A} } within the post B body text. (except no space between the two right hand curly braces)

Your profile description area can also use the double-curly brace include command.


### Template tags

If you want, you can use the opening and closing ``tmpl`` tags around the text to be included, so that only the text within the template tags will be included into another page. That way you can provide additional information about the template within the template page but not have this additional content included into another blog post.

* tmpl. = opening template tag
* tmpl.. = closing template tag
* Both must start at the beginning of a line. The opening tag can precede the text or exist on its own line.


## Custom formatting commands

Textile-like:

A few other formatting commands were added, and they work similar to the Textile commands.

* q. and q..
* tmpl. and tmpl..
* hr.
* br.
* more.
* code. and code..
* fence. and fence..


* q. and q.. To highlight or quote text from another source, surround it with the opening and closing ``q`` tags. Both must start at the beginning of the line.

q.
Here is some text being quoted from another article. Instead of using italics or double quotes, leave the text as is but surround it with the open and closing ``q`` tags. This highlighted text will be indented a little, and it will have a blue-grey background.
q..

* br. To add a blank line, start this command at he beginning of the line. It can precede text, or it can be on its own line. If the latter, Textile will surround the command with paragraph tags, which will cause a total of two blank lines to be displayed. 

* hr. Will add a horizontal rule or a long thin line that stretches across the page. Command must start at the beginning of a line. Example output:

* tmpl. and tmpl.. Used when creating template articles that typically get included into another article. Explained above template includes section.


## Bracket case

A wiki-like feature.

Double-bracket case surrounding the title of an existing post will automatically be turned into a link to that post.

Example: [[Lake Erie West] ]

(except no space between the right brackets)

Produces: [[Lake Erie West]]

You can also use the vertical bar to display different link text to the user.

Example: [[Lake Erie West | LEW] ]

(again, no space between the right brackts)

Produces: [[Lake Erie West | LEW]]

If a post defined within double brackets does not exist, then nothing happens during PREVIEW. The text and the brackets continue to display as is. No links are created. This indicates to you that the post does not exist. That may be acceptable to you, or it means the title name that you surrounded with double-brackets is incorrect.

If the post does not exist and after the post has been saved, then a draft post is automatically created with the hashtag ``draftstub.`` And a link is automatically created in the formatted content where the double-bracket case was used that links to this new draft page. On your profile page, you can view the stub count and access your stream of stub posts.


## External links

URLs that point to other websites have ``class="extlink"`` added to the HTML anchor tag. Currently, the CSS is defined to display red link text color when mousing over an external link. Obviously, this is not applicable to touch screens. 


## Streams

A stream is simply a list of all the posts created or modified, displayed in reverse chronological order from youngest to oldest.

Streams exist for:

* all posts by all users
* blog posts by all users
* microblog posts by all users
* archive blog posts by all users for month, day, and year
* all posts by all users found meeting the search string criteria
* all posts by all users containing the hashtag(s) searched for
* all posts by a single user
* blog posts by a single user
* microblog posts by a single user
* archive blog posts by a single user for for month, day, and year
* all posts by a single user containing the hashtag(s) searched for
* private blog posts for the logged-in user
* draft posts for the logged-in user
* all posts by followed users for the logged-in user
* all posts that contain the followed tags for the logged-in user
* all replies by others to posts created by the logged-in user
* replies for a single post
** For microblog posts, the entire microblog post is displayed at the top of the page followed by the replies
** For blog posts, only the title of the post is displayed, which is a link to the full post, and then the replies are displayed.
** For blog posts, the replies stream page is separate from the main blog post. When viewing a blog post that contains replies, the replies count and the link to the replies page will be displayed at the bottom of the blog post.

When displaying a stream of posts that contain microblog postings, each microblog post is displayed in its entirety, including on small screens or small views.

When displaying a stream of posts that contain blog postings, the content displayed on the stream page includes: 

* the blog title, which is a link to the full post
* the first 250 characters of the blog post body text
* a "more" link if body text exceeds 250 characters.
* if the ``showintro=no`` command is used within the blog post body text, then only the blog title is displayed along with a "more" link
* when the browser is re-sized smaller or when viewing the site on a small screen, only the blog title is displayed, regardless of the showintro command. 

## Replies

Replies are microblog posts with the same formatting and maximum character limitations as posted above for microblog posts.

Clicking the thread link will display on one page the title for a blog post or the entire microblog post along with all the replies.

You can post reply to a reply.

When viewing a reply post on its own page, links will appear at the top of the page for the parent post being replied to and for the entire discussion thread.

### Notes on My Reply Usage 

I've been using the "reply" function in an unintended way at JotHut. I like creating related microblog posts with the reply function. It makes it easier to view the posts within the same thread or on the same page.

Instead of trying to find and read the related notes on the stream page, which displays posts from youngest to oldest, I can click on the thread link for one of the related replies, and I see all the notes displayed on one page in order from oldest to newest.


## Webmentions

Webmentions could be called remote replies. You can  post your replies on your own websites, and then submit  your reply posts either manually or programmatically to the Junco app.

Junco provides an endpoint URL to receive Webmentions.

Junco also provides a text input field at the bottom of each blog or microblog post that allows you to submit the URL to your reply post. 

Your reply posts could be created on your own blog site or at your social media location. A Facebook note, a Tweet, or a Tumblr blog post could be submitted as a reply.

But the remote reply post or Webmention must contain the URL of the post at Junco that is receiving the reply.

The Junco code will access the Webmention and search the post for the URL of the post at Junco that is being replied to. If the URL exists, the reply is accepted at Junco. If the reply does not exist, then the reply is rejected at Junco.

If the Webmention contains appropriate Microformats, then a snippet of the Webmention will be displayed in the Junco app. With or without Microformats, a link to the Webmention will be displayed in the replies thread for the Junco post.

Even though the JotHut.com installation of the Junco app is restricted to a personal publishing site, another user account exists called "Webmention," which is a mechanical user account that exists to enable JotHut to receive webmentions.

While the Junco code can receive Webmention posts either manually or programmatically, the Junco code currently does not automatically send a Webmention.

If a Junco blog post was created to be a Webmention for another site, Junco does not parse the post, looking for the proper Microformats to determine what site or sites should receive the Webmention ping. If you create a blog post with the Junco app that is meant to be a Webmention, then you would need to use cURL to send the Webmention, or hope that the other site provides a text input field for manually receiving Webmention URLs.

The Webmention post is called the "source." 

The post receiving the Webmention or the post being replied to is called the "target."

When Junco receives a Webmention, it responds with JSON-formatted data, according to the protocol defined at:

<http://webmention.org>

Webmention, Microformats, and many other concepts are part of the Indieweb, and they are further explained at:

* <http://indiewebcamp.com>
* <http://indiewebcamp.com/webmention>
* <http://microformats.org/wiki/microformats2>

Example usage at JotHut where both the target and source posts were created at JotHut. Basically, I created a Webmention microblog post that was a reply to one of my blog posts. The Webmention could have existed on another website.

http://jothut.com/cgi-bin/junco.pl/replies/4613


## Open Graph and Microformats2

Junco includes some Open Graph and Microformats markup within the HTML that it produces.

You can also include Microformats within a blog post.

More information about these topics:

* <http://ogp.me>
* <http://microformats.org/wiki/Main_Page>

This markup data can make it easier for programs to share information with other programs.



## Shorter URLs for Posts

A Junco URL for microblog and blog posts can contain information, such as the created or modified date and the title. This can make for a long URL.

A shorter version of the URLs exist where the word "microblogpost" is shortened to 'm' and the word "blogpost" is shortened to 'b' and the post ID number follows for both. 

Example:

* /cgi-bin/blogpost/12345/this-is-a-test-blog-post

can also be accessed via the URL:

* /cgi-bin/b/12345

The same applies for microblog posts with using the letter 'm.'

The word "post" can be used before the post ID number for blog and microblog posts:

* /cgi-bin/post/12345

Junco will determine the post type and display it accordingly. This could have been the default, but I like having the metadata in the URL that indicates the post type: blogpost or microblogpost.


## Syndicating to Posts to Twitter

Currently, it's done manually by clicking the Twitter share button on each Junco post while logged into Twitter. It's a lo-fi approach for now.


## Wiki links

Bracket case: [ [text here] ]

Bracket case but displaying different text to user: [ [Actual title text|displayed title] ]

If the article doesn't exist, a draft post is created with the hashtags "draftstub."

If the article does exists, then bracket case will be converted to a web link, pointing to the existing article.

This article is titled JotHut About. If you want to create a link in another article pointing to this help page, type  [ [JotHut About] ]. Since JotHut About already exists, the bracket case will be converted to the link: [[JotHut About]] .

Camel Case linking does not exist.


### Bracket case chars

* Alphanumeric plus underscore
* Whitespace
* Dash 
* Period 
* Vertical bar 
* Colon 
* Apostrophe 


##  Displayed web links

When mousing over an internal link, the link will become underlined with the link color remaining either blue for unvisited or purple for visited.

When mousing over external links, the link color changes to red.


## Junco Social Features

Social features that exist in the Junco code include:

* multiple user account creation
* following users
* following tags
* replies
* webmentions, which are a form of replies




Chiliproject Tipit Mailgun handler plugin
=========================================

This plug allows to receive emails from Mailgun and also provides  some other email-related features like:

* Target project routing, the target can be specific using the "+" symbol the email addres. For example, if you want to send an email to project1 then you could write to chiliproject+project1@yourchiliserver.com.
* Reject mails with CC, the goal of this feature is to force all comminution to go through Chili.
* Process emails with embedded images to show then in the Issue body
* Identify source application used to send the email and save this information to database. This information is useful to enhance the plugin


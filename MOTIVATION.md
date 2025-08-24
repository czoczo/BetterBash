# tl;dr
The motivation behind the project is to have beautiful Bash on steroids in a few clicks.

# Motivation
Here are a couple of ideas that led to the creation of BetterBash:

## Modern look and feel 
There are shells that are better suited to today's user needs with their functionality, like `zsh` or `fish` to name a few. Bash, despite its years, is still a living project, and its configuration capabilities can surprise you. The BetterBash project aims to "squeeze" as much as possible from Bash to make it more like a modern shell. The theme itself is heavily inspired by the ["jonathan" theme from zsh](https://github.com/ohmyzsh/ohmyzsh/blob/master/themes/jonathan.zsh-theme).

## No dependencies and no need to escalate permissions
One of the goals behind the project is zero dependencies. To use BetterBash, all you need is... `Bash` itself. Admittedly, the presence of `curl` or `wget` will make installation easier, but it is also possible using the system `git` or `openssl`. Installation/update/uninstallation is done with a single call. A similar mindset is used in the permissions area. Installation does not require root, it is done only in user space.

## Git support
It is impossible to talk about a modern shell without built-in facilities for Git users. BetterBash has a built-in [`git-prompt.sh`](https://raw.githubusercontent.com/git/git/master/contrib/completion/git-prompt.sh) that, if you navigate to a folder with a Git repository, displays information about its status.

## With unixporn devotees in mind
Did you happen to come across the perfect shell theme for you, but it didn't match your setup color-wise? With BetterBash this problem does not exist. At your disposal you have [project homepage](https://betterbash.cz0.cz) where with a few clicks you can set and preview the color set to your liking. Each color set has a unique URL, which you can 
save for later or share with others!

## Sensible configuration
In addition to the visual aspects, the project also aims to provide sensible configuration. For the moment, this is limited to configuring the `.inputrc` file to allow history searching using the character prefix. In other words, BetterBash makes it so that you can type the first couple of letters of a command, and use the up arrow on the keyboard to search for command calls that start with the selected letters. There may be more configuration elements in the future. 

## Dedicated to users of multiple hosts
When working with SSH and dozens of active sessions to servers, it is not difficult to make mistakes and execute a command on the wrong host. BetterBash has a feature unheard of anywhere else that generates unique avatars based on the hostname. A bit like the default user avatars on Stack Overflow. Having a unique graphic per host makes it harder to confuse windows. This feature is optional.

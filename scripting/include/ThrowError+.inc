/*
**
*/
#include <sourcepawn>

#if defined _INCLUDE_included
 #endinput
#endif
#define _INCLUDE_included

#define try tryException = true
#define tryEnd tryException = false

#define catch catchException = true
#define catchEnd catchException = false

public bool tryException = false;
public bool catchException = false;
bool waitingToCatch = false;

enum HandleMethod
{
	ServerConsole = 0,
	AllChat = 1
};

public toggleTry(bool enabled)
{
	if (enabled)
	{
		tryException = true;
	} else {
		tryException = false;
	}
}

public void *ThrowErrorPlus(void *Throw, HandleMethod:Method)
{
	if (Method == )
}
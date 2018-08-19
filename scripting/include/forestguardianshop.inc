/*
**
*/
#if defined _INCLUDE_included
 #endinput
#endif
#define _INCLUDE_included

int classselecting[MAXPLAYERS + 1] = 0;

LoadShop(client)
{
	Handle menu = CreateMenu(class_shop, MenuAction_Select | MenuAction_End);
	SetMenuTitle(menu, "Class Shop");

	AddMenuItem(menu, "cg_sirshootsalot", "Shootsalot (Guardian Sniper)");
	AddMenuItem(menu, "cg_phoenix", "Phoenix (Guardian Soldier)");
	AddMenuItem(menu, "cg_rogue", "Rogue (Guardian Spy)");
	AddMenuItem(menu, "cg_medved", "Medved (Guardian Heavy)");
	AddMenuItem(menu, "cb_biker", "Biker (Bandit Scout)");

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public class_shop(Handle menu, MenuAction action, param1, param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			//param1 is client, param2 is item
			char item[64];
			GetMenuItem(menu, param2, item, sizeof(item));

			if (StrEqual(item, "cg_sirshootsalot"))
			{
				LoadItem(param1, "Shootsalot (Guardian Sniper)", 100, "", 10);
			}
			else if (StrEqual(item, "cg_phoenix"))
			{
				LoadItem(param1, "Phoenix (Guardian Soldier)", 100, "", 11);
			}
			else if (StrEqual(item, "cg_rogue"))
			{
				LoadItem(param1, "Rogue (Guardian Spy)", 100, "", 12);
			}
			else if (StrEqual(item, "cg_medved"))
			{
				LoadItem(param1, "Medved (Guardian Heavy)", 100, "", 13);
			}
			else if (StrEqual(item, "cb_biker"))
			{
				LoadItem(param1, "Biker (Bandit Scout)", 100, "", 14);
			}
		}

		case MenuAction_End:
		{
			//param1 is MenuEnd reason, if canceled param2 is MenuCancel reason
			CloseHandle(menu);

		}

	}
}

LoadItem(client, char name[48], int price, char description[64]="", int classnum)
{
	Handle desc = CreateMenu(item_desc, MenuAction_Select | MenuAction_End);
	char wholedesc[128];
	Format(wholedesc, 128, "%s\n%d Karma\n%s", name, price, description);
	SetMenuTitle(desc, wholedesc);
	AddMenuItem(desc, "buy", "Buy");
}

public item_desc(Handle desc, MenuAction action, param1, param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			//param1 is client, param2 is item
			char item[64];
			GetMenuItem(desc, param2, item, sizeof(item));

			if (StrEqual(item, "buy"))
			{
				
			}
		}

		case MenuAction_End:
		{
			//param1 is MenuEnd reason, if canceled param2 is MenuCancel reason
			CloseHandle(desc);

		}

	}
}


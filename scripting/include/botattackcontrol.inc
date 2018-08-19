#if defined _botattackcontrol_included
  #endinput
#endif
#define _botattackcontrol_included

/**
 * @brief Called when bots determine if a player is an enemy.
 *
 * @param bot		Client index of the bot.
 * @param player	Client index of the player.
 * @param result	Contains the original result. Can be changed.
 * @return 			Plugin_Changed to use the result param, Plugin_Continue otherwise.
 *
 * @note			Called several times per tick with bots in the server.
 */
forward Action:OnShouldBotAttackPlayer(bot, player, &bool:result);


public Extension:__ext_botattackcontrol =
{
	name = "botattackcontrol",
	file = "botattackcontrol.ext",
#if defined AUTOLOAD_EXTENSIONS
	autoload = 1,
#else
	autoload = 0,
#endif
#if defined REQUIRE_EXTENSIONS
	required = 1,
#else
	required = 0,
#endif
};

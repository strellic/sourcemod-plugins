#if defined _skillbot_included_
  #endinput
#endif
#define _skillbot_included_
 
/**
 * Returns character's rank formatted for chat as a string.
 *
 * @param int    Client index to be checked.
 * @param string String to be set.
 * @param int    Maxlength of string to be set.
 */
native SB_GetChatRank(client, String:rank[], maxlen);

/**
 * Returns character's rank number.
 *
 * @param int    Client index to be checked.
 */
native SB_GetRank(client);

/**
 * Returns rank number formatted for menus as a string.
 *
 * @param int    Rank index.
 * @param string String to be set.
 * @param int    Maxlength of string to be set.
 */
native SB_GetRank2(ranknum, String:rank[], maxlen);

/**
 * Sets client's point value.
 *
 * @param int    Client index to be checked.
 */
native SB_SetPoints(client, amount);

/**
 * Adds points to client.
 *
 * @param int    Client index to be checked.
 */
native SB_AddPoints(client, amount);

/**
 * Subtracts points from client.
 *
 * @param int    Client index to be checked.
 */
native SB_SubPoints(client, amount);

/**
 * Returns client's current point value.
 *
 * @param int    Client index to be checked.
 */
native SB_GetPoints(client);
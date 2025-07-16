#!/usr/bin/env python
# -*- coding: utf-8 -*-
import asyncio
from calendar import c
import iterm2
#


async def switch_default_profile(connection):
    profiles = await iterm2.PartialProfile.async_query(connection)
    for profile in profiles:
        print(f"Profile: {profile.name}")
        if profile.name == "Default":
            print(f"Switching to profile: {profile.name}")

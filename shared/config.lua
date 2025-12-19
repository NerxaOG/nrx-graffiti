Config = {}

-- General Settings
Config.MaxGraffitiPerPlayer = 5
Config.DefaultSize = 1.0 
Config.MinSize = 0.3                     
Config.MaxSize = 4.0                     
Config.SizeStep = 0.25

-- Render Settings
Config.RenderDistance = 50.0             -- keep this realistic, dont be fucking stupid
Config.MaxVisibleGraffiti = 50           -- performance HEAVY, TEST THIS HARD AF

-- Items
Config.SprayPaintItem = 'spray_paint'  
Config.ScraperItem = 'paint_scraper'

-- Placement Settings
Config.MaxPlacementDistance = 5.0 
Config.PlacementRaycastDistance = 15.0 -- this shit is dumb af, not even sure it fucking works right
Config.RotationStep = 2.0 -- this is same shit as raycast. 

-- Removal Settings
Config.RemovalTime = 10000   -- this is SECONDS
Config.RequireScraperToRemove = true     -- keep as true

-- make this table empty, and everything should fucking work aye
Config.AllowedImageDomains = {
    'imgur.com',
    'i.imgur.com',
    'cdn.discordapp.com',
    'media.discordapp.net',
    'i.ibb.co',
    'fivemanage.com',
    'r2.fivemanage.com',
    'api.fivemanage.com',
}

-- Debug Mode
Config.Debug = true  -- Enable for testing, disable in production

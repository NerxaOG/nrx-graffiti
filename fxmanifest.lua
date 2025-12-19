fx_version 'cerulean'
game 'gta5'

name 'nrx-graffiti'
description 'basic graffiti system'
author 'Nerxa'
version '1.0.0'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'ox_inventory',
    'ox_target',
}

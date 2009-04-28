declare
[Roads] = {Module.link ['x-ozlib://wmeyer/roads/Roads.ozf']}
in
{Roads.registerApplication poll 'x-ozlib://wmeyer/pollapp/PollApp.ozf'}
{Roads.run}

declare
[Roads] = {Module.link ['x-ozlib://wmeyer/roads/Roads.ozf']}
in
{Roads.registerApplication poll 'x-ozlib://wmeyer/pollapp/PollApp.ozf'}
{Roads.setOption useLocalAsAppServer false}
{Roads.addAppServer otherlocal init options(restart:0)}
{Roads.run}

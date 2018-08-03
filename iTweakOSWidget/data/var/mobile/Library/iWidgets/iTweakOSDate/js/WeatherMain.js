
Weather({
    code : weathercode,
    temp : celsius,
    language : language,
    gps : gpsswitch,
    refresh : refreshrate, // in minutes
    success: function(w){
        
document.getElementById('desc').innerHTML = Fcondition[w.icon]; //condition in different languages

        document.getElementById('temp').innerHTML = w.temp + '&deg;';
        document.getElementById('cityname').innerHTML = w.city;
        document.getElementById('weatherIcon').src = 'Images/Spils/' + w.icon + '.png';
        document.getElementById('low').innerHTML = w.low + "&deg;";
        document.getElementById('high').innerHTML = w.high + "&deg;";

    }
});
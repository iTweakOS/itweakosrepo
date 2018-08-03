clock({
  twentyfour : twentyfour,
  padzero : padzero,
  lang : language,
  refresh : refresh,
  success: function(clock){


document.getElementById('hour').innerHTML = clock.hour(true,true); //returns the current hour set to 24hr with the zero padded

document.getElementById('minute').innerHTML = clock.minute();

document.getElementById('today').innerHTML = clock.daytext(); //returns the current day.

document.getElementById('date').innerHTML = clock.date(); //returns the current date.
      
document.getElementById('month').innerHTML = clock.monthtext(); //returns the word of the current month.

  }
});
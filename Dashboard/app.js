// create our angular module and inject firebase
var app = angular.module('scheduleApp', ['firebase'])

// create our main controller and get access to firebase
app.controller('mainController', function($scope, $firebaseArray) {

  // our application code will go here
  var ref = new Firebase("https://printer-status.firebaseio.com/Printers")
  $scope.printers = $firebaseArray(ref);
  var query = ref.orderByChild("Toner/TonerAverage/Percentage");
  $scope.filteredPrinters = $firebaseArray(query);
  $scope.curr_color = "TonerAverage"

  $scope.SortToner = function(color) {
    console.log(color);
    $scope.curr_color = color
    console.log($scope.curr_color)
    query = ref.orderByChild("Toner/" + color +  "/Percentage")
    $scope.filteredPrinters = $firebaseArray(query);
  };
});

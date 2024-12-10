// Add your API endpoint here
const API_ENDPOINT = "https://fcj7on9107.execute-api.eu-west-1.amazonaws.com/prod/students";

// AJAX POST request to save student data
document.getElementById("savestudent").onclick = function(){
    var inputData = {
        "id": $('#studentid').val(),
        "name": $('#name').val(),
        "class": $('#class').val(),
        "age": $('#age').val()
    };
    $.ajax({
        url: API_ENDPOINT,
        type: 'POST',
        data:  JSON.stringify(inputData),
        contentType: 'application/json; charset=utf-8',
        success: function (response) {
            document.getElementById("studentSaved").innerHTML = "Student Data Saved!";
        },
        error: function () {
            alert("Error saving student data.");
        }
    });
}

// AJAX GET request to retrieve all students
document.getElementById("getstudents").onclick = function(){  
    $.ajax({
        url: API_ENDPOINT,
        type: 'GET',
        contentType: 'application/json; charset=utf-8',
        success: function (response) {
            // Ensure response is parsed as JSON
            const students = JSON.parse(response.body);  // Parse JSON string if necessary

            // Clear any existing rows in the table except for the header row
            $('#studentTable tbody').empty();

            // Iterate over each student and append a row to the table
            students.forEach(function(data) {
                $("#studentTable tbody").append("<tr> \
                    <td>" + data['id'] + "</td> \
                    <td>" + data['name'] + "</td> \
                    <td>" + data['class'] + "</td> \
                    <td>" + data['age'] + "</td> \
                </tr>");
            });
        },
        error: function () {
            alert("Error retrieving student data.");
        }
    });
}

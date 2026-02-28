import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/run_data.dart';

class RunSummaryScreen extends StatelessWidget {
  final RunData run;

  const RunSummaryScreen({super.key, required this.run});

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat.yMMMMd().format(run.startTime.toLocal());
    final formattedStartTime = DateFormat.jm().format(run.startTime.toLocal());
    final formattedEndTime = DateFormat.jm().format(run.endTime.toLocal());

    final routePoints = run.route.map((p) => LatLng(p.latitude, p.longitude)).toList();
    final hasRoute = routePoints.isNotEmpty;

    final screenHeight = MediaQuery.of(context).size.height;
    final mapHeight = (screenHeight * 0.28).clamp(0.0, 220.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Run Summary"),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Date and Time
              Text(
                formattedDate,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                "Start: $formattedStartTime  •  End: $formattedEndTime",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),

              // Main Stats Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(child: _statBox("Distance", run.formattedDistance)),
                      Expanded(child: _statBox("Duration", run.formattedDuration)),
                      Expanded(child: _statBox("Pace", run.formattedPace)),
                      Expanded(child: _statBox("Calories", run.formattedCalories)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Optional: More detailed stats if available
              if (run.averageSpeedKmh != null)
                _detailStatRow("Avg Speed", "${run.averageSpeedKmh!.toStringAsFixed(1)} km/h"),
              if (run.maxSpeedKmh != null)
                _detailStatRow("Max Speed", "${run.maxSpeedKmh!.toStringAsFixed(1)} km/h"),
              if (run.elevationGainMeters != null)
                _detailStatRow("Elevation Gain", "${run.elevationGainMeters!.toStringAsFixed(0)} m"),
              if (run.elevationLossMeters != null)
                _detailStatRow("Elevation Loss", "${run.elevationLossMeters!.toStringAsFixed(0)} m"),
              const SizedBox(height: 20),

              // Map Route
              if (hasRoute)
                SizedBox(
                  height: mapHeight,
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: routePoints.first,
                          zoom: 15,
                        ),
                        polylines: {
                          Polyline(
                            polylineId: const PolylineId('run_route'),
                            points: routePoints,
                            color: Colors.blue,
                            width: 5,
                          )
                        },
                        markers: {
                          Marker(
                            markerId: const MarkerId("start"),
                            position: routePoints.first,
                            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                          ),
                          if (routePoints.length > 1)
                            Marker(
                              markerId: const MarkerId("end"),
                              position: routePoints.last,
                              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                            ),
                        },
                        myLocationEnabled: false,
                        zoomControlsEnabled: false,
                        scrollGesturesEnabled: false,
                        rotateGesturesEnabled: false,
                        tiltGesturesEnabled: false,
                        zoomGesturesEnabled: false,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  height: mapHeight,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      "No route data available",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),

              const SizedBox(height: 30),

              // Done Button
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text("DONE", style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _statBox(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _detailStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}


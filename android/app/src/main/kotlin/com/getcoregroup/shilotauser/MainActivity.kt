package com.getcoregroup.shilotauser

import android.content.pm.PackageManager
import android.preference.PreferenceManager
import com.google.android.libraries.places.api.Places
import com.google.android.libraries.places.api.model.AutocompleteSessionToken
import com.google.android.libraries.places.api.model.Place
import com.google.android.libraries.places.api.net.FetchPlaceRequest
import com.google.android.libraries.places.api.net.FindAutocompletePredictionsRequest
import com.google.android.libraries.places.api.net.PlacesClient
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var placesClient: PlacesClient? = null
    private val placesSessions = mutableMapOf<String, AutocompleteSessionToken>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val googleApiKey = readGoogleApiKey()
        if (googleApiKey.isNotEmpty() && !Places.isInitialized()) {
            Places.initialize(applicationContext, googleApiKey)
        }
        if (googleApiKey.isNotEmpty()) {
            placesClient = Places.createClient(this)
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "shilota/widget_shortcuts",
        ).setMethodCallHandler { call, result ->
            if (call.method == "syncSavedPlaces") {
                val homeLabel = call.argument<String>("homeLabel") ?: "Home"
                val workLabel = call.argument<String>("workLabel") ?: "Work"
                val prefs = PreferenceManager.getDefaultSharedPreferences(this)
                prefs.edit()
                    .putString("widget_home_label", homeLabel)
                    .putString("widget_work_label", workLabel)
                    .apply()
                FavoriteShortcutWidget.refreshAll(this)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "shilota/app_config",
        ).setMethodCallHandler { call, result ->
            if (call.method == "getGoogleApiKey") {
                try {
                    val appInfo = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
                    val apiKey = appInfo.metaData?.getString("com.google.android.geo.API_KEY").orEmpty()
                    result.success(apiKey)
                } catch (exception: Exception) {
                    result.success("")
                }
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "shilota/places",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "autocomplete" -> {
                    val query = call.argument<String>("query").orEmpty().trim()
                    val sessionTokenValue = call.argument<String>("sessionToken").orEmpty().trim()
                    if (query.length < 2) {
                        result.success(emptyList<Map<String, Any?>>())
                        return@setMethodCallHandler
                    }
                    val client = placesClient
                    if (client == null) {
                        result.success(emptyList<Map<String, Any?>>())
                        return@setMethodCallHandler
                    }
                    val tokenKey = if (sessionTokenValue.isNotEmpty()) {
                        sessionTokenValue
                    } else {
                        "default"
                    }
                    val token = placesSessions.getOrPut(tokenKey) {
                        AutocompleteSessionToken.newInstance()
                    }
                    val request = FindAutocompletePredictionsRequest.builder()
                        .setCountry("TZ")
                        .setSessionToken(token)
                        .setQuery(query)
                        .build()
                    client.findAutocompletePredictions(request)
                        .addOnSuccessListener { response ->
                            val items = response.autocompletePredictions.map { prediction ->
                                mapOf(
                                    "placeId" to prediction.placeId,
                                    "title" to prediction.getPrimaryText(null).toString(),
                                    "subtitle" to prediction.getSecondaryText(null)?.toString(),
                                )
                            }
                            result.success(items)
                        }
                        .addOnFailureListener { exception ->
                            result.error(
                                "PLACES_AUTOCOMPLETE_FAILED",
                                exception.message ?: "Unable to fetch autocomplete predictions",
                                null,
                            )
                        }
                }
                "fetchPlaceDetails" -> {
                    val placeId = call.argument<String>("placeId").orEmpty().trim()
                    if (placeId.isEmpty()) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    val client = placesClient
                    if (client == null) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    val sessionTokenValue = call.argument<String>("sessionToken").orEmpty().trim()
                    val fields = listOf(
                        Place.Field.ID,
                        Place.Field.NAME,
                        Place.Field.ADDRESS,
                        Place.Field.LAT_LNG,
                    )
                    val requestBuilder = FetchPlaceRequest.builder(placeId, fields)
                    if (sessionTokenValue.isNotEmpty()) {
                        placesSessions[sessionTokenValue]?.let { requestBuilder.setSessionToken(it) }
                    }
                    client.fetchPlace(requestBuilder.build())
                        .addOnSuccessListener { response ->
                            val place = response.place
                            val latLng = place.latLng
                            result.success(
                                mapOf(
                                    "placeId" to place.id,
                                    "title" to (place.name ?: ""),
                                    "subtitle" to (place.address ?: ""),
                                    "latitude" to latLng?.latitude,
                                    "longitude" to latLng?.longitude,
                                ),
                            )
                            if (sessionTokenValue.isNotEmpty()) {
                                placesSessions.remove(sessionTokenValue)
                            }
                        }
                        .addOnFailureListener { exception ->
                            result.error(
                                "PLACES_DETAILS_FAILED",
                                exception.message ?: "Unable to fetch place details",
                                null,
                            )
                            if (sessionTokenValue.isNotEmpty()) {
                                placesSessions.remove(sessionTokenValue)
                            }
                        }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun readGoogleApiKey(): String {
        val buildConfigKey = BuildConfig.API_KEY.trim()
        if (buildConfigKey.isNotEmpty()) {
            return buildConfigKey
        }
        return try {
            val appInfo = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
            appInfo.metaData?.getString("com.google.android.geo.API_KEY").orEmpty()
        } catch (exception: Exception) {
            ""
        }
    }
}

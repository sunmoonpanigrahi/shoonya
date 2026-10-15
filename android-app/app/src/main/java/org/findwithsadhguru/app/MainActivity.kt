package org.findwithsadhguru.app

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.speech.RecognizerIntent
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Article
import androidx.compose.material.icons.filled.Headphones
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale
import java.util.concurrent.TimeUnit

private val Forest = Color(0xFF315B46)
private val Paper = Color(0xFFF7F6F0)
private val Ink = Color(0xFF20251F)
private val Muted = Color(0xFF69736A)

data class CatalogItem(
    val type: String,
    val title: String,
    val summary: String,
    val url: String,
    val source: String,
    val date: String,
    val tags: String,
    val terms: String,
)

data class CatalogSnapshot(val items: List<CatalogItem>, val updatedAt: String)

object CatalogRepository {
    private const val MAX_CATALOG_BYTES = 12 * 1024 * 1024

    fun read(context: android.content.Context): CatalogSnapshot {
        val cached = File(context.filesDir, "catalog.json")
        val raw = if (cached.exists()) cached.readText(Charsets.UTF_8) else
            context.assets.open("catalog.json").bufferedReader(Charsets.UTF_8).use { it.readText() }
        return parse(raw)
    }

    fun refresh(context: android.content.Context): CatalogSnapshot? {
        val endpoint = BuildConfig.CATALOG_URL.trim()
        if (endpoint.isEmpty()) return null
        val parsedUrl = URL(endpoint)
        require(parsedUrl.protocol == "https") { "The catalog endpoint must use HTTPS." }
        val connection = parsedUrl.openConnection() as HttpURLConnection
        connection.connectTimeout = 15_000
        connection.readTimeout = 30_000
        connection.requestMethod = "GET"
        connection.setRequestProperty("Accept", "application/json")
        connection.setRequestProperty("User-Agent", "FindWithSadhguru-Android/1.0")
        try {
            if (connection.responseCode !in 200..299) error("Catalog server returned ${connection.responseCode}.")
            val bytes = connection.inputStream.use { input ->
                val output = java.io.ByteArrayOutputStream()
                val buffer = ByteArray(8192)
                var total = 0
                while (true) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    total += count
                    require(total <= MAX_CATALOG_BYTES) { "Catalog is larger than expected." }
                    output.write(buffer, 0, count)
                }
                output.toByteArray()
            }
            val body = bytes.toString(Charsets.UTF_8)
            val snapshot = parse(body)
            require(snapshot.items.isNotEmpty()) { "The catalog contains no official results." }
            File(context.filesDir, "catalog.json").writeText(body, Charsets.UTF_8)
            context.getSharedPreferences("catalog", 0).edit()
                .putString("last_sync", java.time.Instant.now().toString())
                .apply()
            return snapshot
        } finally {
            connection.disconnect()
        }
    }

    fun lastSync(context: android.content.Context): String =
        context.getSharedPreferences("catalog", 0).getString("last_sync", "") ?: ""

    private fun parse(raw: String): CatalogSnapshot {
        val root = JSONObject(raw)
        val array = root.optJSONArray("items") ?: error("Catalog has no items array.")
        val records = buildList {
            for (index in 0 until array.length()) {
                val item = array.optJSONObject(index) ?: continue
                val type = item.optString("type").lowercase(Locale.ROOT)
                val url = item.optString("url")
                if (type !in setOf("article", "video", "audio") || !isOfficialUrl(url)) continue
                val title = item.optString("title").trim()
                if (title.isEmpty()) continue
                add(
                    CatalogItem(
                        type = type,
                        title = title,
                        summary = item.optString("summary").trim(),
                        url = url,
                        source = item.optString("source", "Isha • Wisdom"),
                        date = item.optString("date"),
                        tags = item.optString("tags"),
                        terms = item.optString("terms"),
                    ),
                )
            }
        }
        return CatalogSnapshot(records, root.optString("generated_at"))
    }

    private fun isOfficialUrl(value: String): Boolean = try {
        val uri = Uri.parse(value)
        uri.scheme == "https" && uri.host == "isha.sadhguru.org"
    } catch (_: Exception) {
        false
    }
}

class CatalogSyncWorker(context: android.content.Context, params: androidx.work.WorkerParameters) :
    androidx.work.CoroutineWorker(context, params) {
    override suspend fun doWork(): Result = try {
        withContext(Dispatchers.IO) { CatalogRepository.refresh(applicationContext) }
        Result.success()
    } catch (_: Exception) {
        Result.retry()
    }
}

class MainActivity : ComponentActivity() {
    private var onVoiceResult: ((String) -> Unit)? = null
    private val voiceLauncher = registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        if (result.resultCode == Activity.RESULT_OK) {
            val phrase = result.data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.firstOrNull()
            if (!phrase.isNullOrBlank()) onVoiceResult?.invoke(phrase)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        scheduleCatalogRefresh()
        setContent {
            val context = LocalContext.current
            var query by remember { mutableStateOf("") }
            var snapshot by remember { mutableStateOf(CatalogSnapshot(emptyList(), "")) }
            var loading by remember { mutableStateOf(true) }
            var refreshing by remember { mutableStateOf(false) }
            var syncMessage by remember { mutableStateOf("Loading the included official catalog…") }
            var selectedType by remember { mutableStateOf("all") }
            val scope = rememberCoroutineScope()

            fun refreshCatalog() {
                if (refreshing) return
                refreshing = true
                syncMessage = "Checking for new official content…"
                scope.launch {
                    val fresh = withContext(Dispatchers.IO) {
                        runCatching { CatalogRepository.refresh(context) }.getOrNull()
                    }
                    if (fresh != null) {
                        snapshot = fresh
                        syncMessage = "Updated ${formatCount(fresh.items.size)} official pages"
                    } else if (BuildConfig.CATALOG_URL.isBlank()) {
                        syncMessage = "Included index · waiting for the live catalog address"
                    } else {
                        syncMessage = "Showing the saved index · refresh will retry when online"
                    }
                    refreshing = false
                    loading = false
                }
            }

            LaunchedEffect(Unit) {
                snapshot = withContext(Dispatchers.IO) { runCatching { CatalogRepository.read(context) }.getOrDefault(CatalogSnapshot(emptyList(), "")) }
                loading = false
                syncMessage = "Included index · checking for updates"
                refreshCatalog()
            }

            onVoiceResult = { query = it }
            val voiceSearch: () -> Unit = {
                try {
                    val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-IN")
                        putExtra(RecognizerIntent.EXTRA_PROMPT, "Speak a topic or question")
                    }
                    voiceLauncher.launch(intent)
                } catch (_: ActivityNotFoundException) {
                    syncMessage = "Voice search is unavailable on this device. Type your search instead."
                }
            }

            MaterialTheme(colorScheme = lightColorScheme(primary = Forest, background = Paper, surface = Color.White, onBackground = Ink, onSurface = Ink)) {
                Surface(modifier = Modifier.fillMaxSize(), color = Paper) {
                    Column(modifier = Modifier.fillMaxSize()) {
                        AppHeader(refreshing = refreshing, onRefresh = ::refreshCatalog)
                        LazyColumn(modifier = Modifier.fillMaxSize(), contentPadding = androidx.compose.foundation.layout.PaddingValues(start = 20.dp, end = 20.dp, top = 20.dp, bottom = 32.dp)) {
                            item {
                                Text("A library of wisdom", color = Forest, fontSize = 12.sp, fontWeight = FontWeight.Bold, letterSpacing = 2.sp)
                                Text("Find what you’re\nlooking for.", fontFamily = FontFamily.Serif, fontSize = 42.sp, lineHeight = 46.sp, color = Ink, modifier = Modifier.padding(top = 11.dp))
                                Text("Search public Sadhguru content from official Isha sources.", color = Muted, fontSize = 15.sp, modifier = Modifier.padding(top = 10.dp, bottom = 18.dp))
                                SearchBox(value = query, onValueChange = { query = it }, onVoice = voiceSearch)
                                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 12.dp, bottom = 16.dp)) {
                                    listOf("Anxiety", "Save Soil", "Stress", "Sleep").forEach { suggestion ->
                                        FilterChip(selected = false, onClick = { query = suggestion }, label = { Text(suggestion, fontSize = 12.sp) })
                                    }
                                }
                                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp)) {
                                    if (refreshing || loading) CircularProgressIndicator(modifier = Modifier.size(14.dp), strokeWidth = 2.dp, color = Forest)
                                    Text(syncMessage, color = Muted, fontSize = 11.sp, modifier = Modifier.weight(1f).padding(start = 7.dp))
                                    Text("${formatCount(snapshot.items.size)} indexed", color = Muted, fontSize = 11.sp)
                                }
                            }
                            if (query.isNotBlank()) {
                                val found = searchCatalog(snapshot.items, query).filter { selectedType == "all" || it.first.type == selectedType }
                                item {
                                    Row(verticalAlignment = Alignment.Bottom, modifier = Modifier.fillMaxWidth().padding(top = 8.dp, bottom = 12.dp)) {
                                        Text("Results for ‘${query.trim()}’", fontFamily = FontFamily.Serif, fontSize = 25.sp, modifier = Modifier.weight(1f))
                                        Text("${found.size} results", color = Muted, fontSize = 12.sp)
                                    }
                                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.padding(bottom = 12.dp)) {
                                        listOf("all", "video", "article", "audio").forEach { type ->
                                            FilterChip(selected = selectedType == type, onClick = { selectedType = type }, label = { Text(type.replaceFirstChar { it.titlecase() }, fontSize = 11.sp) })
                                        }
                                    }
                                }
                                item {
                                    YouTubeSearchCard(query = query, onOpen = {
                                        val youtubeUrl = Uri.parse("https://www.youtube.com/@sadhguru/search")
                                            .buildUpon().appendQueryParameter("query", query.trim()).build().toString()
                                        openPublicSource(youtubeUrl)
                                    })
                                }
                                if (found.isEmpty()) item {
                                    Text("No matching official pages yet. Try ‘soil’, ‘anxiety’, ‘stress’ or ‘sleep’.", color = Muted, modifier = Modifier.padding(vertical = 26.dp))
                                }
                                items(found, key = { it.first.url }) { (item, _) -> ResultCard(item = item, onOpen = { openPublicSource(item.url) }) }
                            } else {
                                item {
                                    Text("Official channels", color = Muted, fontSize = 12.sp, modifier = Modifier.padding(top = 8.dp, bottom = 6.dp))
                                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.horizontalScroll(rememberScrollState())) {
                                        officialChannels.forEach { (name, url) ->
                                            FilterChip(selected = false, onClick = { openPublicSource(url) }, label = { Text(name, fontSize = 12.sp) })
                                        }
                                    }
                                    Text("Only links to public official pages are indexed. Media stays with its publisher.", color = Muted, fontSize = 11.sp, modifier = Modifier.padding(top = 16.dp))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private fun scheduleCatalogRefresh() {
        if (BuildConfig.CATALOG_URL.isBlank()) return
        val constraints = Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()
        val request = PeriodicWorkRequestBuilder<CatalogSyncWorker>(24, TimeUnit.HOURS)
            .setConstraints(constraints)
            .build()
        WorkManager.getInstance(applicationContext).enqueueUniquePeriodicWork(
            "official-catalog-refresh",
            ExistingPeriodicWorkPolicy.KEEP,
            request,
        )
    }

    private fun openPublicSource(url: String) {
        val uri = Uri.parse(url)
        val allowed = uri.scheme == "https" && uri.host in setOf(
            "isha.sadhguru.org", "www.youtube.com", "www.instagram.com", "www.facebook.com",
            "www.linkedin.com", "x.com",
        )
        if (!allowed) return
        runCatching { startActivity(Intent(Intent.ACTION_VIEW, uri)) }
    }
}

@Composable
private fun AppHeader(refreshing: Boolean, onRefresh: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().background(Color.White).padding(horizontal = 20.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(modifier = Modifier.size(34.dp).clip(CircleShape).background(Forest), contentAlignment = Alignment.Center) {
            Text("S", color = Color.White, fontFamily = FontFamily.Serif, fontSize = 20.sp)
        }
        Text("Find with Sadhguru", fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f).padding(start = 10.dp))
        Text("Independent · official sources", color = Muted, fontSize = 10.sp)
        IconButton(onClick = onRefresh, enabled = !refreshing) {
            Icon(Icons.Default.Refresh, contentDescription = "Refresh catalog", tint = Forest)
        }
    }
}

@Composable
private fun SearchBox(value: String, onValueChange: (String) -> Unit, onVoice: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(15.dp)).background(Color.White).padding(start = 15.dp, end = 7.dp, top = 6.dp, bottom = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Default.Search, contentDescription = null, tint = Muted)
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier.weight(1f).padding(horizontal = 10.dp, vertical = 13.dp),
            singleLine = true,
            textStyle = androidx.compose.ui.text.TextStyle(color = Ink, fontSize = 14.sp),
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
            keyboardActions = KeyboardActions(onSearch = {}),
            decorationBox = { inner ->
                Box {
                    if (value.isEmpty()) Text("Search a question or topic", color = Muted, fontSize = 14.sp)
                    inner()
                }
            },
        )
        IconButton(onClick = onVoice) { Icon(Icons.Default.Mic, contentDescription = "Search by voice", tint = Forest) }
    }
}

@Composable
private fun ResultCard(item: CatalogItem, onOpen: () -> Unit) {
    val icon = when (item.type) {
        "video" -> Icons.Default.PlayArrow
        "audio" -> Icons.Default.Headphones
        else -> Icons.Default.Article
    }
    Card(
        modifier = Modifier.fillMaxWidth().padding(bottom = 11.dp).clickable(onClick = onOpen),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
    ) {
        Column(modifier = Modifier.padding(17.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(icon, contentDescription = null, tint = Forest, modifier = Modifier.size(17.dp))
                Text("  ${item.type.uppercase(Locale.ROOT)}", color = Muted, fontSize = 10.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
            }
            Text(item.title, fontFamily = FontFamily.Serif, fontSize = 21.sp, lineHeight = 25.sp, modifier = Modifier.padding(top = 9.dp, bottom = 7.dp))
            if (item.summary.isNotBlank()) Text(item.summary, color = Muted, fontSize = 13.sp, lineHeight = 19.sp, maxLines = 3, overflow = TextOverflow.Ellipsis)
            Spacer(Modifier.height(11.dp))
            Text(listOfNotNull(item.source.ifBlank { "Isha • Wisdom" }, item.date.takeIf { it.isNotBlank() }).joinToString(" · "), color = Muted, fontSize = 10.sp)
        }
    }
}

@Composable
private fun YouTubeSearchCard(query: String, onOpen: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth().padding(bottom = 11.dp).clickable(onClick = onOpen),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(containerColor = Color(0xFFEAF0E6)),
    ) {
        Row(modifier = Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Default.PlayArrow, contentDescription = null, tint = Forest)
            Column(modifier = Modifier.padding(start = 9.dp)) {
                Text("Search official Sadhguru videos", color = Forest, fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
                Text("Open YouTube results for ‘${query.trim()}’", color = Muted, fontSize = 12.sp)
            }
        }
    }
}

private val officialChannels = listOf(
    "YouTube" to "https://www.youtube.com/@sadhguru",
    "Instagram" to "https://www.instagram.com/sadhguru/",
    "Facebook" to "https://www.facebook.com/sadhguru",
    "LinkedIn" to "https://www.linkedin.com/in/sadhgurujv/",
    "X" to "https://x.com/SadhguruJV",
)

private fun formatCount(count: Int): String = String.format(Locale.getDefault(), "%,d", count)

private fun searchCatalog(items: List<CatalogItem>, query: String): List<Pair<CatalogItem, Int>> {
    val normalized = query.lowercase(Locale.ROOT)
    val terms = normalized.split(Regex("[^\\p{L}\\p{N}]+"))
        .filter { it.length > 2 && it !in setOf("how", "what", "for", "with", "the", "and", "you") }
        .toMutableSet()
    val expansions = mapOf(
        "anxiety" to listOf("anxious", "worry", "worried", "fear", "nervous"),
        "stress" to listOf("tension", "overwhelmed", "anxiety"),
        "soil" to listOf("save soil", "soil degradation", "soil revitalization", "environment", "ecology"),
        "sleep" to listOf("rest", "sleep peacefully"),
        "peace" to listOf("calm", "inner peace"),
    )
    expansions.forEach { (key, extra) -> if (normalized.contains(key)) terms.addAll(extra) }
    if (terms.isEmpty()) return emptyList()
    return items.mapNotNull { item ->
        val title = item.title.lowercase(Locale.ROOT)
        val description = "${item.summary} ${item.tags} ${item.terms}".lowercase(Locale.ROOT)
        val score = terms.sumOf { word -> (if (title.contains(word)) 4 else 0) + (if (description.contains(word)) 1 else 0) }
        if (score > 0) item to score else null
    }.sortedWith(compareByDescending<Pair<CatalogItem, Int>> { it.second }.thenBy { it.first.title })
}


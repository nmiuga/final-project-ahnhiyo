#  Initial Prompt (Generated from ClaudeAI)

Create a multi-view SwiftUI app called "What Are We Eating?" — 
a fully featured nearby restaurant discovery app with a bold, 
cinematic dark aesthetic.

The app should be fully functional with live data from the Google Places API.

ARCHITECTURE:
- RestaurantService.swift — handles all Google Places API calls
- Restaurant.swift — data model
- ContentView.swift — main entry point and navigation
- SearchView.swift — location search and filter UI
- SwipeView.swift — tinder-style swipe through restaurants
- ResultsView.swift — scrollable list of all results with sort options
- DetailView.swift — full restaurant detail page
- FavoritesView.swift — saved/favorited restaurants
- FavoritesManager.swift — ObservableObject that persists 
  favorites using UserDefaults
- Use @StateObject, @ObservedObject, and @EnvironmentObject 
  for state management
- Use async/await for all network calls
- Use NavigationStack for navigation between views

GOOGLE PLACES API INTEGRATION:
- API Key stored in Constants.swift as:
  let GOOGLE_PLACES_API_KEY = "YOUR_KEY_HERE"
- Step 1: Text Search endpoint to find restaurants near location:
  https://maps.googleapis.com/maps/api/place/textsearch/json
  ?query=restaurants+near+LOCATION
  &type=restaurant
  &key=API_KEY
- Step 2: Place Details endpoint for full restaurant info:
  https://maps.googleapis.com/maps/api/place/details/json
  ?place_id=PLACE_ID
  &fields=name,formatted_address,rating,price_level,
  opening_hours,photos,formatted_phone_number,website,types
  &key=API_KEY
- Step 3: Places Photo endpoint for images:
  https://maps.googleapis.com/maps/api/place/photo
  ?maxwidth=800
  &photo_reference=PHOTO_REFERENCE
  &key=API_KEY
- Parse the following fields for each restaurant:
  - name
  - place_id
  - formatted_address
  - rating (Double)
  - price_level (convert to $ symbols)
  - opening_hours.open_now (Bool)
  - opening_hours.weekday_text (array of strings for hours)
  - photos[0].photo_reference
  - formatted_phone_number
  - website
  - types[0] (cuisine label, strip underscores)
  - geometry.location.lat and .lng (for distance + directions)
- Calculate distance from searched location to each restaurant 
  using CLLocation and display in miles
- Load all images via AsyncImage
- Handle errors gracefully with user-facing error messages

RESTAURANT MODEL (Restaurant.swift):
struct Restaurant: Identifiable, Codable {
  let id: String (use place_id)
  let name: String
  let address: String
  let rating: Double
  let priceLevel: Int
  let isOpenNow: Bool
  let cuisine: String
  let photoReference: String?
  let phoneNumber: String?
  let website: String?
  let weekdayHours: [String]
  let latitude: Double
  let longitude: Double
  var distanceMiles: Double?
  var isFavorited: Bool = false
}

FAVORITES (FavoritesManager.swift):
- ObservableObject class
- @Published var favorites: [Restaurant]
- func toggleFavorite(_ restaurant: Restaurant)
- func isFavorited(_ restaurant: Restaurant) -> Bool
- Persist to UserDefaults using JSONEncoder/JSONDecoder
- Inject into environment so all views can access it

SEARCH & FILTER VIEW (SearchView.swift):
- App title "What Are We Eating?" at top, large, bold, orange (#FF5C35)
- TextField for location input with dark styling
- "Find Restaurants" button in orange that triggers API call
- Filter section with the following controls:
  - Cuisine filter: horizontal scrollable pill buttons 
    (All, Mexican, Italian, Chinese, Japanese, American, 
    Indian, Thai, Mediterranean, Fast Food)
  - Price filter: segmented picker ($, $$, $$$, $$$$, Any)
  - "Open Now" toggle switch
  - Distance radius slider from 0.5 to 10 miles with label
  - Sort by picker: Rating, Distance, Price (low to high), 
    Price (high to low)
- A large "Surprise Me!" button that randomly selects one 
  restaurant from results and navigates directly to its DetailView
- After search completes, show two tab buttons: 
  "Swipe" and "List" to switch between SwipeView and ResultsView

SWIPE VIEW (SwipeView.swift):
- Tinder-style card swipe interface
- Show one restaurant card at a time, large and full-width
- Card contains: photo (300pt height), name, cuisine, 
  price, rating, distance, open/closed status
- Swipe right or tap "Yes!" button = add to favorites
- Swipe left or tap "Nope" button = skip
- Animated card transition between restaurants
- Show a green heart overlay when swiping right
- Show a red X overlay when swiping left
- When all cards are swiped, show a summary screen:
  "You liked X places!" with a button to view favorites
- Progress indicator showing X of Y restaurants

RESULTS LIST VIEW (ResultsView.swift):
- Scrollable VStack of restaurant cards inside a ScrollView
- Each card is a VStack:
  photo (210pt, clipped, cornerRadius 14, 
  .saturation(0.85) image modifier applied to all photos) →
  name heading → cuisine + price subheading in orange (#FFB347) →
  rating + open status body → distance + address detail
- Cards: dark background (#1A1A1A), corner radius 18, 
  16pt inner padding, 1pt border (#2A2A2A)
- 20pt spacing between cards
- Sort bar at top with active sort displayed
- Tap any card to navigate to DetailView
- Heart button on each card to toggle favorite inline
- Overall background: #0E0E0E

DETAIL VIEW (DetailView.swift):
- Full screen detail page for a single restaurant
- Large hero photo at top (280pt), with gradient overlay 
  from clear to black at the bottom
- Restaurant name as large title below photo
- Cuisine type and price in orange
- Star rating displayed with SF Symbol stars
- Open/closed status with green or red dot indicator
- Full address
- All weekly opening hours listed
- Phone number as a tappable tel: link
- Website as a tappable link
- "Get Directions" button that opens Apple Maps with the 
  restaurant's coordinates:
  let url = URL(string: "maps://?daddr=LAT,LON")
- "Share" button that triggers iOS share sheet using ShareLink, 
  sharing the restaurant name and address as text
- Heart/favorite button in the top right navigation bar
- Back button to return to results

FAVORITES VIEW (FavoritesView.swift):
- Accessible from a heart tab in a bottom TabView
- List of all favorited restaurants
- Same card design as ResultsView
- Tap to go to DetailView
- Swipe to delete from favorites
- Empty state: centered message "No favorites yet — 
  start swiping to save places!" with a fork SF Symbol

NAVIGATION & TABS:
- Bottom TabView with three tabs:
  - Search tab (magnifying glass SF Symbol)
  - Favorites tab (heart SF Symbol) with badge showing count
  - A "Surprise Me!" tab (dice SF Symbol) that immediately 
    picks a random restaurant from the last search results 
    and navigates to its DetailView

IMAGE HANDLING:
- All photos loaded via AsyncImage from Google Places Photo URL
- Fixed consistent heights per context (210pt list, 300pt swipe, 280pt detail)
- .clipped() and appropriate .cornerRadius() on all images
- .saturation(0.85) applied to all restaurant photos for a 
  consistent, slightly muted cinematic look
- Loading placeholder: dark gray Rectangle() with centered ProgressView()
- Error placeholder: dark Rectangle() with centered 
  fork.knife SF Symbol in orange (#FF5C35)

STATES TO HANDLE:
- Empty: "Enter a location to discover restaurants near you"
- Loading: centered ProgressView() with "Finding restaurants..."
- Error: centered error message in red with a retry button
- No results: "No restaurants found — try adjusting your filters"
- No favorites: empty state message in FavoritesView

OVERALL FEEL:
Dark and cinematic. Warm orange accents (#FF5C35 primary, #FFB347 secondary). Every restaurant should feel worth visiting. 
Clean, confident, and visually striking. Background #0E0E0E throughout.


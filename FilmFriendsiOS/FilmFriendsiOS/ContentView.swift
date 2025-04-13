// FilmGear - Eine App zum Teilen von Filmequipment zwischen Filmemachern
// Swift / SwiftUI Code für iOS

import SwiftUI
import UIKit
import Firebase
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

// MARK: - App Entry Point
@main
struct FilmGearApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
        }
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        if authViewModel.isSignedIn {
            MainTabView()
        } else {
            AuthView()
        }
    }
}

// MARK: - Authentication
class AuthViewModel: ObservableObject {
    @Published var isSignedIn = false
    @Published var currentUser: User?
    @Published var errorMessage = ""
    
    private var handle: AuthStateDidChangeListenerHandle?
    
    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] (_, user) in
            self?.isSignedIn = user != nil
            self?.currentUser = user
        }
    }
    
    func signIn(email: String, password: String) {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                self?.errorMessage = error.localizedDescription
            }
        }
    }
    
    func signUp(email: String, password: String, username: String) {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                self?.errorMessage = error.localizedDescription
                return
            }
            
            if let uid = result?.user.uid {
                let userData = [
                    "email": email,
                    "username": username,
                    "createdAt": Timestamp(date: Date())
                ]
                
                Firestore.firestore().collection("users").document(uid).setData(userData)
            }
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    deinit {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}

struct AuthView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                
                Text("FilmGear")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Verleihe dein Filmequipment an andere Filmmaker")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                if !authViewModel.errorMessage.isEmpty {
                    Text(authViewModel.errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
                
                VStack(spacing: 15) {
                    TextField("Email", text: $email)
                        .keyboardType(UIKeyboardType.emailAddress)               // bisher unverändert
                        .textInputAutocapitalization(.never)       // neu in SwiftUI
                        .autocorrectionDisabled(true)              // ersetzt autocorrection
                        .padding()

                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                    
                    if isSignUp {
                        TextField("Benutzername", text: $username)
                            .autocapitalization(.none)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                    }
                    
                    SecureField("Passwort", text: $password)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                    
                    Button(action: {
                        if isSignUp {
                            authViewModel.signUp(email: email, password: password, username: username)
                        } else {
                            authViewModel.signIn(email: email, password: password)
                        }
                    }) {
                        Text(isSignUp ? "Registrieren" : "Anmelden")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                
                Button(action: {
                    isSignUp.toggle()
                }) {
                    Text(isSignUp ? "Bereits registriert? Anmelden" : "Neu hier? Registrieren")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Startseite")
                }
                .tag(0)
            
            ExploreView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Entdecken")
                }
                .tag(1)
            
            CreateListingView()
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                    Text("Hinzufügen")
                }
                .tag(2)
            
            MessagesView()
                .tabItem {
                    Image(systemName: "message.fill")
                    Text("Nachrichten")
                }
                .tag(3)
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profil")
                }
                .tag(4)
        }
    }
}

// MARK: - Home View
struct HomeView: View {
    @StateObject private var viewModel = EquipmentViewModel()
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.featuredItems) { item in
                    NavigationLink(destination: EquipmentDetailView(equipment: item)) {
                        EquipmentListItemView(equipment: item)
                    }
                }
            }
            .navigationTitle("FilmGear")
            .navigationBarItems(trailing: Button(action: {}) {
                Image(systemName: "bell")
            })
            .onAppear {
                viewModel.fetchFeaturedItems()
            }
        }
    }
}

// MARK: - Explore View
struct ExploreView: View {
    @State private var searchText = ""
    @StateObject private var viewModel = EquipmentViewModel()
    @State private var filterCategory: EquipmentCategory?
    
    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $searchText, onSearch: {
                    viewModel.searchEquipment(query: searchText)
                })
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        ForEach(EquipmentCategory.allCases) { category in
                            CategoryFilterButton(
                                category: category,
                                isSelected: filterCategory == category,
                                action: {
                                    if filterCategory == category {
                                        filterCategory = nil
                                    } else {
                                        filterCategory = category
                                    }
                                    viewModel.filterByCategory(category: filterCategory)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                
                List {
                    ForEach(viewModel.filteredItems) { item in
                        NavigationLink(destination: EquipmentDetailView(equipment: item)) {
                            EquipmentListItemView(equipment: item)
                        }
                    }
                }
            }
            .navigationTitle("Entdecken")
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    var onSearch: () -> Void
    
    var body: some View {
        HStack {
            TextField("Suche nach Equipment...", text: $text)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .onSubmit {
                    onSearch()
                }
            
            Button(action: onSearch) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.blue)
            }
            .padding(.trailing)
        }
    }
}

struct CategoryFilterButton: View {
    let category: EquipmentCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(category.displayName)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

// MARK: - Create Listing View
struct CreateListingView: View {
    @StateObject private var viewModel = CreateListingViewModel()
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showAlert = false
    @State private var navigateToHome = false
    
    struct RootView: View {
        @State private var path: [String] = []  // Beispiel: Array für deine Navigation

        var body: some View {
            NavigationStack(path: $path) {
                HomeView()
                    .navigationDestination(for: String.self) { value in
                        // Hier entscheidest du, welche View angezeigt wird
                        if value == "home" {
                            HomeView()
                        } else {
                            // andere Ziele
                        }
                    }
            }
        }
    }

    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Informationen")) {
                    TextField("Titel", text: $viewModel.title)
                    Picker("Kategorie", selection: $viewModel.category) {
                        ForEach(EquipmentCategory.allCases) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    TextField("Preis pro Tag (€)", text: $viewModel.pricePerDay)
                        .keyboardType(.decimalPad)
                    TextField("Beschreibung", text: $viewModel.description)
                        .frame(height: 100)
                }
                
                Section(header: Text("Verfügbarkeit")) {
                    DatePicker("Von", selection: $viewModel.availableFrom, displayedComponents: .date)
                    DatePicker("Bis", selection: $viewModel.availableUntil, displayedComponents: .date)
                }
                
                Section(header: Text("Bilder")) {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                    }
                    
                    Button(action: {
                        showImagePicker = true
                    }) {
                        HStack {
                            Image(systemName: "camera")
                            Text(selectedImage == nil ? "Bild hinzufügen" : "Bild ändern")
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        if viewModel.validateForm() {
                            viewModel.createListing(image: selectedImage) { success in
                                if success {
                                    showAlert = true
                                    viewModel.resetForm()
                                    selectedImage = nil
                                }
                            }
                        }
                    }) {
                        Text("Inserat erstellen")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(Color.blue)
                    .disabled(!viewModel.isFormValid)
                }
            }
            .navigationTitle("Equipment anbieten")
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage)
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Erfolgreich"),
                    message: Text("Dein Equipment wurde erfolgreich eingestellt."),
                    dismissButton: .default(Text("OK"), action: {
                        navigateToHome = true
                    })
                )
            }
            .background(
                //NavigationLink(destination: HomeView(), isActive: $navigateToHome) {
                .navigationDestination(isPresented: $navigateToHome) {
                    EmptyView()
                }
            )
        }
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Messages View
struct MessagesView: View {
    @StateObject private var viewModel = MessagesViewModel()
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.conversations) { conversation in
                    NavigationLink(destination: ChatView(conversation: conversation)) {
                        ConversationRow(conversation: conversation)
                    }
                }
            }
            .navigationTitle("Nachrichten")
            .onAppear {
                viewModel.fetchConversations()
            }
        }
    }
}

struct ConversationRow: View {
    let conversation: Conversation
    
    var body: some View {
        HStack(spacing: 12) {
            if let urlString = conversation.otherUserImageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Color.gray
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.otherUserName)
                    .font(.headline)
                
                Text(conversation.lastMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(conversation.formattedTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if conversation.unreadCount > 0 {
                    Text("\(conversation.unreadCount)")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ChatView: View {
    let conversation: Conversation
    @StateObject private var viewModel = ChatViewModel()
    @State private var messageText = ""
    
    var body: some View {
        VStack {
            ScrollView {
                LazyVStack {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                    }
                }
                .padding()
            }
            
            HStack {
                TextField("Nachricht", text: $messageText)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                
                Button(action: {
                    if !messageText.isEmpty {
                        viewModel.sendMessage(text: messageText, conversationId: conversation.id)
                        messageText = ""
                    }
                }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.blue)
                        .padding(10)
                }
            }
            .padding()
        }
        .navigationTitle(conversation.otherUserName)
        .onAppear {
            viewModel.fetchMessages(conversationId: conversation.id)
        }
    }
}

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isFromCurrentUser {
                Spacer()
                Text(message.text)
                    .padding(12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(18)
            } else {
                Text(message.text)
                    .padding(12)
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(18)
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Profile View
struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showEditProfile = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .center, spacing: 20) {
                    if let urlString = viewModel.profileImageURL, let url = URL(string: urlString) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Color.gray
                        }
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 120, height: 120)
                            .foregroundColor(.gray)
                    }
                    
                    Text(viewModel.username)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(viewModel.bio)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: {
                        showEditProfile = true
                    }) {
                        Text("Profil bearbeiten")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(20)
                    }
                    .padding(.top)
                    
                    Divider()
                        .padding(.vertical)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Meine Angebote")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if viewModel.userListings.isEmpty {
                            Text("Noch keine Angebote erstellt")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 15) {
                                    ForEach(viewModel.userListings) { item in
                                        NavigationLink(destination: EquipmentDetailView(equipment: item)) {
                                            EquipmentCardView(equipment: item)
                                                .frame(width: 200)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    Button(action: {
                        authViewModel.signOut()
                    }) {
                        Text("Abmelden")
                            .foregroundColor(.red)
                            .padding()
                    }
                    .padding(.top)
                }
                .padding()
            }
            .navigationTitle("Profil")
            .onAppear {
                viewModel.fetchUserProfile()
                viewModel.fetchUserListings()
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView(
                    username: viewModel.username,
                    bio: viewModel.bio,
                    profileImageURL: viewModel.profileImageURL,
                    onSave: { username, bio, image in
                        viewModel.updateProfile(username: username, bio: bio, image: image)
                    }
                )
            }
        }
    }
}

struct EditProfileView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var username: String
    @State private var bio: String
    @State private var profileImageURL: String?
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    
    let onSave: (String, String, UIImage?) -> Void
    
    init(username: String, bio: String, profileImageURL: String?, onSave: @escaping (String, String, UIImage?) -> Void) {
        self._username = State(initialValue: username)
        self._bio = State(initialValue: bio)
        self._profileImageURL = State(initialValue: profileImageURL)
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profilbild")) {
                    HStack {
                        Spacer()
                        
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else if let urlString = profileImageURL, let url = URL(string: urlString) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Color.gray
                            }
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 100, height: 100)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical)
                    
                    Button(action: {
                        showImagePicker = true
                    }) {
                        Text("Bild ändern")
                    }
                }
                
                Section(header: Text("Informationen")) {
                    TextField("Benutzername", text: $username)
                    
                    TextField("Über mich", text: $bio)
                        .frame(height: 100)
                }
            }
            .navigationTitle("Profil bearbeiten")
            .navigationBarItems(
                leading: Button("Abbrechen") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Speichern") {
                    onSave(username, bio, selectedImage)
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage)
            }
        }
    }
}

// MARK: - Equipment Detail View
struct EquipmentDetailView: View {
    let equipment: Equipment
    @StateObject private var viewModel = EquipmentDetailViewModel()
    @State private var showDatePicker = false
    @State private var rentStartDate = Date()
    @State private var rentEndDate = Date().addingTimeInterval(86400) // +1 day
    @State private var showContactSheet = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Image carousel
                TabView {
                    ForEach(equipment.imageURLs, id: \.self) { urlString in
                        if let url = URL(string: urlString) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Color.gray
                            }
                        }
                    }
                }
                .tabViewStyle(PageTabViewStyle())
                .frame(height: 300)
                
                VStack(alignment: .leading, spacing: 15) {
                    Text(equipment.title)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    HStack {
                        Text("\(equipment.pricePerDay)€ pro Tag")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Text(equipment.category.displayName)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                    
                    Divider()
                    
                    Text("Beschreibung")
                        .font(.headline)
                    
                    Text(equipment.description)
                        .font(.body)
                    
                    Divider()
                    
                    Text("Verfügbarkeit")
                        .font(.headline)
                    
                    HStack {
                        Text("Von: \(equipment.formattedAvailableFrom)")
                        Spacer()
                        Text("Bis: \(equipment.formattedAvailableUntil)")
                    }
                    .font(.subheadline)
                    
                    Divider()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Anbieter")
                                .font(.headline)
                            
                            HStack {
                                if let urlString = viewModel.ownerImageURL, let url = URL(string: urlString) {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    } placeholder: {
                                        Color.gray
                                    }
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .frame(width: 40, height: 40)
                                        .foregroundColor(.gray)
                                }
                                
                                Text(viewModel.ownerName)
                                    .font(.body)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.favoriteTapped(equipment: equipment)
                        }) {
                            Image(systemName: viewModel.isFavorite ? "heart.fill" : "heart")
                                .foregroundColor(viewModel.isFavorite ? .red : .gray)
                                .font(.title2)
                        }
                    }
                    
                    if showDatePicker {
                        VStack(spacing: 15) {
                            DatePicker("Von", selection: $rentStartDate, in: equipment.availableFrom...equipment.availableUntil, displayedComponents: .date)
                            
                            DatePicker("Bis", selection: $rentEndDate, in: rentStartDate...equipment.availableUntil, displayedComponents: .date)
                            
                            Text("Gesamtpreis: \(viewModel.calculateTotalPrice(equipment: equipment, startDate: rentStartDate, endDate: rentEndDate))€")
                                .font(.headline)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    
                    HStack(spacing: 15) {
                        Button(action: {
                            showDatePicker.toggle()
                        }) {
                            Text(showDatePicker ? "Zeitraum schließen" : "Zeitraum auswählen")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        
                        Button(action: {
                            showContactSheet = true
                        }) {
                            Text("Kontaktieren")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Equipment Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadOwnerInfo(ownerId: equipment.ownerId)
            viewModel.checkIfFavorite(equipmentId: equipment.id)
        }
        .sheet(isPresented: $showContactSheet) {
            ContactOwnerView(
                equipment: equipment,
                ownerName: viewModel.ownerName,
                startDate: rentStartDate,
                endDate: rentEndDate
            )
        }
    }
}

struct ContactOwnerView: View {
    let equipment: Equipment
    let ownerName: String
    let startDate: Date
    let endDate: Date
    
    @State private var messageText = ""
    @StateObject private var viewModel = ContactViewModel()
    @Environment(\.presentationMode) var presentationMode
    @State private var showAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Nachricht an \(ownerName)")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Angefragt: \(equipment.title)")
                        .font(.subheadline)
                    
                    HStack {
                        Text("Von: \(startDate.formatted(date: .abbreviated, time: .omitted))")
                        Spacer()

                             Text("Bis: \(endDate.formatted(date: .abbreviated, time: .omitted))")
                                                 }
                                                 .font(.subheadline)
                                             }
                                             .padding()
                                             .background(Color(.systemGray6))
                                             .cornerRadius(10)
                                             
                                             TextEditor(text: $messageText)
                                                 .frame(minHeight: 150)
                                                 .padding(5)
                                                 .overlay(
                                                     RoundedRectangle(cornerRadius: 10)
                                                         .stroke(Color.gray, lineWidth: 1)
                                                 )
                                                 .padding(.horizontal)
                                                 .overlay(
                                                     VStack {
                                                         if messageText.isEmpty {
                                                             HStack {
                                                                 Text("Schreibe deine Nachricht hier...")
                                                                     .foregroundColor(.gray)
                                                                     .padding(.horizontal, 13)
                                                                     .padding(.top, 13)
                                                                 Spacer()
                                                             }
                                                         }
                                                     }, alignment: .topLeading
                                                 )
                                             
                                             Button(action: {
                                                 viewModel.sendMessage(
                                                     ownerId: equipment.ownerId,
                                                     equipmentId: equipment.id,
                                                     message: messageText,
                                                     startDate: startDate,
                                                     endDate: endDate
                                                 ) { success in
                                                     if success {
                                                         showAlert = true
                                                     }
                                                 }
                                             }) {
                                                 Text("Nachricht senden")
                                                     .font(.headline)
                                                     .foregroundColor(.white)
                                                     .frame(maxWidth: .infinity)
                                                     .padding()
                                                     .background(Color.blue)
                                                     .cornerRadius(10)
                                             }
                                             .padding()
                                             .disabled(messageText.isEmpty)
                                         }
                                         .padding()
                                         .navigationBarTitle("Kontakt", displayMode: .inline)
                                         .navigationBarItems(trailing: Button("Abbrechen") {
                                             presentationMode.wrappedValue.dismiss()
                                         })
                                         .alert(isPresented: $showAlert) {
                                             Alert(
                                                 title: Text("Nachricht gesendet"),
                                                 message: Text("Deine Anfrage wurde erfolgreich gesendet."),
                                                 dismissButton: .default(Text("OK"), action: {
                                                     presentationMode.wrappedValue.dismiss()
                                                 })
                                             )
                                         }
                                     }
                                 }
                             }

                             // MARK: - Helper Views
                             struct EquipmentListItemView: View {
                                 let equipment: Equipment
                                 
                                 var body: some View {
                                     HStack(spacing: 15) {
                                         if let urlString = equipment.imageURLs.first, let url = URL(string: urlString) {
                                             AsyncImage(url: url) { image in
                                                 image
                                                     .resizable()
                                                     .scaledToFill()
                                             } placeholder: {
                                                 Color.gray
                                             }
                                             .frame(width: 80, height: 80)
                                             .clipShape(RoundedRectangle(cornerRadius: 8))
                                         } else {
                                             Rectangle()
                                                 .fill(Color.gray)
                                                 .frame(width: 80, height: 80)
                                                 .clipShape(RoundedRectangle(cornerRadius: 8))
                                         }
                                         
                                         VStack(alignment: .leading, spacing: 5) {
                                             Text(equipment.title)
                                                 .font(.headline)
                                                 .lineLimit(1)
                                             
                                             Text(equipment.category.displayName)
                                                 .font(.caption)
                                                 .foregroundColor(.secondary)
                                             
                                             Text("\(equipment.pricePerDay)€ pro Tag")
                                                 .font(.subheadline)
                                                 .fontWeight(.semibold)
                                                 .foregroundColor(.blue)
                                             
                                             Text(equipment.location)
                                                 .font(.caption)
                                                 .foregroundColor(.secondary)
                                         }
                                     }
                                 }
                             }

                             struct EquipmentCardView: View {
                                 let equipment: Equipment
                                 
                                 var body: some View {
                                     VStack(alignment: .leading, spacing: 8) {
                                         if let urlString = equipment.imageURLs.first, let url = URL(string: urlString) {
                                             AsyncImage(url: url) { image in
                                                 image
                                                     .resizable()
                                                     .scaledToFill()
                                             } placeholder: {
                                                 Color.gray
                                             }
                                             .frame(height: 140)
                                             .clipShape(RoundedRectangle(cornerRadius: 8))
                                         } else {
                                             Rectangle()
                                                 .fill(Color.gray)
                                                 .frame(height: 140)
                                                 .clipShape(RoundedRectangle(cornerRadius: 8))
                                         }
                                         
                                         Text(equipment.title)
                                             .font(.headline)
                                             .lineLimit(1)
                                         
                                         Text("\(equipment.pricePerDay)€ pro Tag")
                                             .font(.subheadline)
                                             .fontWeight(.semibold)
                                             .foregroundColor(.blue)
                                         
                                         Text(equipment.category.displayName)
                                             .font(.caption)
                                             .padding(.horizontal, 8)
                                             .padding(.vertical, 4)
                                             .background(Color(.systemGray6))
                                             .cornerRadius(4)
                                     }
                                 }
                             }

                             // MARK: - Models
                             struct Equipment: Identifiable {
                                 let id: String
                                 let title: String
                                 let description: String
                                 let category: EquipmentCategory
                                 let pricePerDay: Double
                                 let ownerId: String
                                 let imageURLs: [String]
                                 let availableFrom: Date
                                 let availableUntil: Date
                                 let location: String
                                 let createdAt: Date
                                 
                                 var formattedAvailableFrom: String {
                                     availableFrom.formatted(date: .abbreviated, time: .omitted)
                                 }
                                 
                                 var formattedAvailableUntil: String {
                                     availableUntil.formatted(date: .abbreviated, time: .omitted)
                                 }
                             }

                             enum EquipmentCategory: String, CaseIterable, Identifiable {
                                 case cameras = "cameras"
                                 case lenses = "lenses"
                                 case lighting = "lighting"
                                 case audio = "audio"
                                 case stabilizers = "stabilizers"
                                 case drones = "drones"
                                 case rigging = "rigging"
                                 case monitors = "monitors"
                                 case other = "other"
                                 
                                 var id: String { self.rawValue }
                                 
                                 var displayName: String {
                                     switch self {
                                     case .cameras: return "Kameras"
                                     case .lenses: return "Objektive"
                                     case .lighting: return "Licht"
                                     case .audio: return "Audio"
                                     case .stabilizers: return "Stabilisierung"
                                     case .drones: return "Drohnen"
                                     case .rigging: return "Rigging"
                                     case .monitors: return "Monitore"
                                     case .other: return "Sonstiges"
                                     }
                                 }
                             }

                             struct Conversation: Identifiable {
                                 let id: String
                                 let otherUserId: String
                                 let otherUserName: String
                                 let otherUserImageURL: String?
                                 let lastMessage: String
                                 let lastMessageTimestamp: Date
                                 let unreadCount: Int
                                 
                                 var formattedTime: String {
                                     let calendar = Calendar.current
                                     if calendar.isDateInToday(lastMessageTimestamp) {
                                         return lastMessageTimestamp.formatted(date: .omitted, time: .shortened)
                                     } else if calendar.isDateInYesterday(lastMessageTimestamp) {
                                         return "Gestern"
                                     } else {
                                         return lastMessageTimestamp.formatted(date: .abbreviated, time: .omitted)
                                     }
                                 }
                             }

                             struct Message: Identifiable {
                                 let id: String
                                 let senderId: String
                                 let text: String
                                 let timestamp: Date
                                 let isFromCurrentUser: Bool
                             }

                             // MARK: - View Models
                             class EquipmentViewModel: ObservableObject {
                                 @Published var featuredItems: [Equipment] = []
                                 @Published var filteredItems: [Equipment] = []
                                 
                                 func fetchFeaturedItems() {
                                     // In a real app, we would fetch from Firebase
                                     // For now, we'll use sample data
                                     featuredItems = sampleEquipment()
                                     filteredItems = featuredItems
                                 }
                                 
                                 func searchEquipment(query: String) {
                                     if query.isEmpty {
                                         filteredItems = featuredItems
                                     } else {
                                         filteredItems = featuredItems.filter { equipment in
                                             equipment.title.lowercased().contains(query.lowercased()) ||
                                             equipment.description.lowercased().contains(query.lowercased()) ||
                                             equipment.category.displayName.lowercased().contains(query.lowercased())
                                         }
                                     }
                                 }
                                 
                                 func filterByCategory(category: EquipmentCategory?) {
                                     if let category = category {
                                         filteredItems = featuredItems.filter { $0.category == category }
                                     } else {
                                         filteredItems = featuredItems
                                     }
                                 }
                                 
                                 // Sample data
                                 private func sampleEquipment() -> [Equipment] {
                                     return [
                                         Equipment(
                                             id: "1",
                                             title: "Sony Alpha 7S III",
                                             description: "Professionelle Vollformatkamera speziell für Video und Low-Light-Aufnahmen. Inkl. 2 Batterien und Ladegerät.",
                                             category: .cameras,
                                             pricePerDay: 89.0,
                                             ownerId: "user1",
                                             imageURLs: ["https://example.com/camera1.jpg"],
                                             availableFrom: Date(),
                                             availableUntil: Date().addingTimeInterval(60*60*24*30), // +30 days
                                             location: "Berlin",
                                             createdAt: Date()
                                         ),
                                         Equipment(
                                             id: "2",
                                             title: "Sennheiser MKH 416",
                                             description: "Professionelles Richtmikrofon für Filmproduktionen. Inkl. Windschutz und XLR-Kabel.",
                                             category: .audio,
                                             pricePerDay: 32.0,
                                             ownerId: "user2",
                                             imageURLs: ["https://example.com/mic1.jpg"],
                                             availableFrom: Date(),
                                             availableUntil: Date().addingTimeInterval(60*60*24*20), // +20 days
                                             location: "Hamburg",
                                             createdAt: Date()
                                         ),
                                         Equipment(
                                             id: "3",
                                             title: "Aputure 300D Mark II",
                                             description: "Leistungsstarker LED-Scheinwerfer mit 300W. Inkl. Fresnel-Vorsatz und Stativ.",
                                             category: .lighting,
                                             pricePerDay: 45.0,
                                             ownerId: "user3",
                                             imageURLs: ["https://example.com/light1.jpg"],
                                             availableFrom: Date(),
                                             availableUntil: Date().addingTimeInterval(60*60*24*15), // +15 days
                                             location: "München",
                                             createdAt: Date()
                                         ),
                                         Equipment(
                                             id: "4",
                                             title: "DJI Ronin RS2",
                                             description: "Professioneller 3-Achsen-Gimbal für Kameras bis 4,5kg. Mit Follow Focus und Schnellwechselplatte.",
                                             category: .stabilizers,
                                             pricePerDay: 38.0,
                                             ownerId: "user1",
                                             imageURLs: ["https://example.com/gimbal1.jpg"],
                                             availableFrom: Date(),
                                             availableUntil: Date().addingTimeInterval(60*60*24*25), // +25 days
                                             location: "Berlin",
                                             createdAt: Date()
                                         ),
                                         Equipment(
                                             id: "5",
                                             title: "Canon EF 24-70mm f/2.8L II",
                                             description: "Professionelles Zoom-Objektiv mit konstanter Blende f/2.8. Mit Gegenlichtblende und Koffer.",
                                             category: .lenses,
                                             pricePerDay: 28.0,
                                             ownerId: "user2",
                                             imageURLs: ["https://example.com/lens1.jpg"],
                                             availableFrom: Date(),
                                             availableUntil: Date().addingTimeInterval(60*60*24*18), // +18 days
                                             location: "Hamburg",
                                             createdAt: Date()
                                         )
                                     ]
                                 }
                             }

                             class CreateListingViewModel: ObservableObject {
                                 @Published var title = ""
                                 @Published var description = ""
                                 @Published var category: EquipmentCategory = .cameras
                                 @Published var pricePerDay = ""
                                 @Published var availableFrom = Date()
                                 @Published var availableUntil = Date().addingTimeInterval(60*60*24*30) // +30 days
                                 
                                 var isFormValid: Bool {
                                     !title.isEmpty && !description.isEmpty && !pricePerDay.isEmpty && availableUntil > availableFrom
                                 }
                                 
                                 func validateForm() -> Bool {
                                     return isFormValid
                                 }
                                 
                                 func createListing(image: UIImage?, completion: @escaping (Bool) -> Void) {
                                     // In a real app, we would upload the image to Firebase Storage
                                     // Then create a document in Firestore
                                     
                                     // Simulate network delay
                                     DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                         completion(true)
                                     }
                                 }
                                 
                                 func resetForm() {
                                     title = ""
                                     description = ""
                                     category = .cameras
                                     pricePerDay = ""
                                     availableFrom = Date()
                                     availableUntil = Date().addingTimeInterval(60*60*24*30)
                                 }
                             }

                             class MessagesViewModel: ObservableObject {
                                 @Published var conversations: [Conversation] = []
                                 
                                 func fetchConversations() {
                                     // In a real app, we would fetch from Firebase
                                     // For now, we'll use sample data
                                     conversations = sampleConversations()
                                 }
                                 
                                 // Sample data
                                 private func sampleConversations() -> [Conversation] {
                                     return [
                                         Conversation(
                                             id: "conv1",
                                             otherUserId: "user1",
                                             otherUserName: "Sarah Schmidt",
                                             otherUserImageURL: nil,
                                             lastMessage: "Ist die Kamera noch verfügbar für den 20.?",
                                             lastMessageTimestamp: Date().addingTimeInterval(-3600), // 1 hour ago
                                             unreadCount: 2
                                         ),
                                         Conversation(
                                             id: "conv2",
                                             otherUserId: "user2",
                                             otherUserName: "Max Müller",
                                             otherUserImageURL: nil,
                                             lastMessage: "Danke für die schnelle Antwort!",
                                             lastMessageTimestamp: Date().addingTimeInterval(-86400), // 1 day ago
                                             unreadCount: 0
                                         ),
                                         Conversation(
                                             id: "conv3",
                                             otherUserId: "user3",
                                             otherUserName: "Lisa Wagner",
                                             otherUserImageURL: nil,
                                             lastMessage: "Alles klar, dann hole ich das Licht morgen ab.",
                                             lastMessageTimestamp: Date().addingTimeInterval(-172800), // 2 days ago
                                             unreadCount: 0
                                         )
                                     ]
                                 }
                             }

                             class ChatViewModel: ObservableObject {
                                 @Published var messages: [Message] = []
                                 
                                 func fetchMessages(conversationId: String) {
                                     // In a real app, we would fetch from Firebase
                                     // For now, we'll use sample data
                                     messages = sampleMessages()
                                 }
                                 
                                 func sendMessage(text: String, conversationId: String) {
                                     let newMessage = Message(
                                         id: UUID().uuidString,
                                         senderId: "currentUser",
                                         text: text,
                                         timestamp: Date(),
                                         isFromCurrentUser: true
                                     )
                                     
                                     messages.append(newMessage)
                                     
                                     // In a real app, we would send this to Firebase
                                 }
                                 
                                 // Sample data
                                 private func sampleMessages() -> [Message] {
                                     return [
                                         Message(
                                             id: "msg1",
                                             senderId: "otherUser",
                                             text: "Hallo! Ich habe gesehen, dass du eine Sony A7S III anbietest. Ist die für nächste Woche noch verfügbar?",
                                             timestamp: Date().addingTimeInterval(-3600 * 5), // 5 hours ago
                                             isFromCurrentUser: false
                                         ),
                                         Message(
                                             id: "msg2",
                                             senderId: "currentUser",
                                             text: "Hallo! Ja, die Kamera ist noch verfügbar. An welchen Tagen genau brauchst du sie?",
                                             timestamp: Date().addingTimeInterval(-3600 * 4), // 4 hours ago
                                             isFromCurrentUser: true
                                         ),
                                         Message(
                                             id: "msg3",
                                             senderId: "otherUser",
                                             text: "Super! Ich würde sie gerne von Montag bis Mittwoch ausleihen. Für ein Musikvideo-Dreh.",
                                             timestamp: Date().addingTimeInterval(-3600 * 2), // 2 hours ago
                                             isFromCurrentUser: false
                                         ),
                                         Message(
                                             id: "msg4",
                                             senderId: "otherUser",
                                             text: "Gibt es bei dir eine Kaution, die ich hinterlegen muss?",
                                             timestamp: Date().addingTimeInterval(-3600), // 1 hour ago
                                             isFromCurrentUser: false
                                         )
                                     ]
                                 }
                             }

                             class ProfileViewModel: ObservableObject {
                                 @Published var username = "Thomas Weber"
                                 @Published var bio = "Filmmaker aus Berlin. Spezialisiert auf Dokumentarfilme und Musikvideos."
                                 @Published var profileImageURL: String? = nil
                                 @Published var userListings: [Equipment] = []
                                 
                                 func fetchUserProfile() {
                                     // In a real app, we would fetch from Firebase
                                 }
                                 
                                 func fetchUserListings() {
                                     // In a real app, we would fetch from Firebase
                                     // For now, we'll use sample data
                                     userListings = [
                                         Equipment(
                                             id: "1",
                                             title: "Sony Alpha 7S III",
                                             description: "Professionelle Vollformatkamera speziell für Video und Low-Light-Aufnahmen.",
                                             category: .cameras,
                                             pricePerDay: 89.0,
                                             ownerId: "currentUser",
                                             imageURLs: ["https://example.com/camera1.jpg"],
                                             availableFrom: Date(),
                                             availableUntil: Date().addingTimeInterval(60*60*24*30),
                                             location: "Berlin",
                                             createdAt: Date()
                                         ),
                                         Equipment(
                                             id: "4",
                                             title: "DJI Ronin RS2",
                                             description: "Professioneller 3-Achsen-Gimbal für Kameras bis 4,5kg.",
                                             category: .stabilizers,
                                             pricePerDay: 38.0,
                                             ownerId: "currentUser",
                                             imageURLs: ["https://example.com/gimbal1.jpg"],
                                             availableFrom: Date(),
                                             availableUntil: Date().addingTimeInterval(60*60*24*25),
                                             location: "Berlin",
                                             createdAt: Date()
                                         )
                                     ]
                                 }
                                 
                                 func updateProfile(username: String, bio: String, image: UIImage?) {
                                     self.username = username
                                     self.bio = bio
                                     
                                     // In a real app, we would upload the image to Firebase Storage
                                     // and update the Firestore document
                                 }
                             }

                             class EquipmentDetailViewModel: ObservableObject {
                                 @Published var ownerName = ""
                                 @Published var ownerImageURL: String? = nil
                                 @Published var isFavorite = false
                                 
                                 func loadOwnerInfo(ownerId: String) {
                                     // In a real app, we would fetch from Firebase
                                     // For now, we'll use sample data
                                     ownerName = "Max Mustermann"
                                 }
                                 
                                 func checkIfFavorite(equipmentId: String) {
                                     // In a real app, we would check in Firestore
                                     isFavorite = false
                                 }
                                 
                                 func favoriteTapped(equipment: Equipment) {
                                     // In a real app, we would update in Firestore
                                     isFavorite.toggle()
                                 }
                                 
                                 func calculateTotalPrice(equipment: Equipment, startDate: Date, endDate: Date) -> String {
                                     let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
                                     let totalDays = max(1, days + 1) // Including first and last day
                                     let totalPrice = Double(totalDays) * equipment.pricePerDay
                                     return String(format: "%.2f", totalPrice)
                                 }
                             }

                             class ContactViewModel: ObservableObject {
                                 func sendMessage(ownerId: String, equipmentId: String, message: String, startDate: Date, endDate: Date, completion: @escaping (Bool) -> Void) {
                                     // In a real app, we would send this to Firebase
                                     
                                     // Simulate network delay
                                     DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                         completion(true)
                                     }
                                 }
                             }

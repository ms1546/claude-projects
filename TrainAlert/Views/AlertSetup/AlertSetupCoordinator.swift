//
//  AlertSetupCoordinator.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import SwiftUI

struct AlertSetupCoordinator: View {
    // MARK: - Properties
    
    @StateObject private var viewModel = AlertSetupViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    let onAlertCreated: (() -> Void)?
    
    // MARK: - State
    
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    // MARK: - Init
    
    init(onAlertCreated: (() -> Void)? = nil) {
        self.onAlertCreated = onAlertCreated
    }
    
    var body: some View {
        ZStack {
            // Main content
            Group {
                switch viewModel.currentStep {
                case .stationSearch:
                    StationSearchView(
                        setupData: viewModel.setupData
                    )                        { station in
                            viewModel.selectStation(station)
                        }
                    
                case .alertSettings:
                    AlertSettingView(
                        setupData: viewModel.setupData,
                        onNext: {
                            viewModel.goToNextStep()
                        },
                        onBack: {
                            viewModel.goToPreviousStep()
                        }
                    )
                    
                case .characterSelection:
                    CharacterSelectView(
                        setupData: viewModel.setupData,
                        onNext: {
                            viewModel.goToNextStep()
                        },
                        onBack: {
                            viewModel.goToPreviousStep()
                        }
                    )
                    
                case .review:
                    AlertReviewView(
                        setupData: viewModel.setupData,
                        onCreateAlert: {
                            handleCreateAlert()
                        },
                        onBack: {
                            viewModel.goToPreviousStep()
                        }
                    )
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)
            
            // Loading Overlay
            if viewModel.isLoading {
                loadingOverlay
            }
        }
        .onReceive(viewModel.$isComplete) { isComplete in
            if isComplete {
                handleAlertCreationSuccess()
            }
        }
        .onReceive(viewModel.$errorMessage) { errorMessage in
            if let errorMessage = errorMessage {
                handleError(errorMessage)
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            if viewModel.isComplete {
                Button("完了") {
                    dismissView()
                }
            } else {
                Button("OK") {
                    viewModel.clearError()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Views
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .trainSoftBlue))
                    .scaleEffect(1.5)
                
                Text("目覚ましを作成中...")
                    .font(.body)
                    .foregroundColor(.textPrimary)
            }
            .padding(24)
            .background(Color.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .transition(.opacity)
    }
    
    // MARK: - Methods
    
    private func handleCreateAlert() {
        Task {
            do {
                let success = try await viewModel.createAlert()
                if success {
                    // Success handling is done through the observer
                }
            } catch {
                // Error handling is done through the observer
            }
        }
    }
    
    private func handleAlertCreationSuccess() {
        alertTitle = "目覚まし作成完了"
        alertMessage = "目覚ましが正常に作成されました。ホーム画面で目覚ましの状態を確認できます。"
        showAlert = true
        
        // Haptic feedback for success
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
    
    private func handleError(_ message: String) {
        alertTitle = "エラー"
        alertMessage = message
        showAlert = true
        
        // Haptic feedback for error
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
    }
    
    private func dismissView() {
        presentationMode.wrappedValue.dismiss()
        onAlertCreated?()
    }
}

// MARK: - Alert Setup Flow Entry Point

struct AlertSetupFlow: View {
    @Environment(\.presentationMode) var presentationMode
    let onAlertCreated: (() -> Void)?
    
    var body: some View {
        AlertSetupCoordinator(onAlertCreated: onAlertCreated)
    }
}

// MARK: - View Modifier for Presenting Alert Setup

struct AlertSetupModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onAlertCreated: (() -> Void)?
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                AlertSetupFlow(onAlertCreated: onAlertCreated)
            }
    }
}

extension View {
    func alertSetup(
        isPresented: Binding<Bool>,
        onAlertCreated: (() -> Void)? = nil
    ) -> some View {
        self.modifier(AlertSetupModifier(
            isPresented: isPresented,
            onAlertCreated: onAlertCreated
        ))
    }
}

// MARK: - Preview

#if DEBUG
struct AlertSetupCoordinator_Previews: PreviewProvider {
    static var previews: some View {
        AlertSetupCoordinator()
            .preferredColorScheme(.dark)
    }
}
#endif

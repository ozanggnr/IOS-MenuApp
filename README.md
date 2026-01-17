# iOS MenuApp

An iOS application built with Swift that demonstrates a dynamic menu system with category-based organization and detailed item views.

## Overview

This project was created as part of an iOS development course to showcase fundamental iOS development concepts including table views, navigation controllers, JSON data parsing, and the Model-View-Controller (MVC) architecture pattern.

## Features

The app provides a restaurant-style menu interface where users can browse different categories of items and view detailed information about each menu item. The menu data is loaded from a JSON file, making it easy to update the content without modifying the code.

## Technical Implementation

The project is built using Swift and UIKit, utilizing CocoaPods for dependency management. The application follows the MVC design pattern to maintain clean separation between data models, user interface, and business logic. Menu items are organized into categories, and users can navigate through the app using standard iOS navigation patterns with table views and detail views.

## Requirements

You'll need Xcode installed on your Mac to run this project, along with CocoaPods for managing the project dependencies. After cloning the repository, run `pod install` in the project directory and open the `.xcworkspace` file to work with the project.

## Getting Started

Clone the repository to your local machine, navigate to the project directory in Terminal, and run `pod install` to install all dependencies. Once complete, open `ZaeriGungor_Project.xcworkspace` in Xcode and build the project to run it on the simulator or a physical device.

## Project Structure

The codebase is organized with the Xcode project and workspace files at the root level, the main application code in the `ZaeriGungor_Project` directory, and menu data stored in the `success.json` file. The Podfile manages external dependencies used throughout the application.
